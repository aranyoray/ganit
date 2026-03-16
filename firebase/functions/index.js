const { onCall, HttpsError } = require("firebase-functions/v2/https");
const admin = require("firebase-admin");
const crypto = require("crypto");
const nodemailer = require("nodemailer");

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────

const CODE_TTL_MS = 10 * 60 * 1000;       // 10 minutes
const MAX_SEND_PER_HOUR = 3;
const MAX_VERIFY_ATTEMPTS = 5;

// SMTP transporter — configure via Firebase environment config:
//   firebase functions:config:set smtp.host="smtp.gmail.com" smtp.port="587"
//   smtp.user="your@gmail.com" smtp.pass="app-password"
//   smtp.from_email="noreply@ganit-app.com" smtp.from_name="Ganit"
function getTransporter() {
  const config = process.env;
  if (config.SMTP_HOST && config.SMTP_USER) {
    return nodemailer.createTransport({
      host: config.SMTP_HOST,
      port: parseInt(config.SMTP_PORT || "587"),
      secure: false,
      auth: { user: config.SMTP_USER, pass: config.SMTP_PASS },
    });
  }
  return null;
}

// ─────────────────────────────────────────────
// sendVerificationCode
// Callable from iOS app. Generates 6-digit code,
// stores hash in Firestore, sends email via SMTP.
// ─────────────────────────────────────────────

exports.sendVerificationCode = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const { email } = request.data;

    if (!email || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Valid email required.");
    }

    const normalizedEmail = email.trim().toLowerCase();
    const docRef = db.collection("verificationCodes").doc(normalizedEmail);

    // Rate limit: check send count in last hour
    const existing = await docRef.get();
    if (existing.exists) {
      const data = existing.data();
      const sendTimes = (data.sendTimes || []).filter(
        (t) => Date.now() - t < 3600000
      );
      if (sendTimes.length >= MAX_SEND_PER_HOUR) {
        throw new HttpsError(
          "resource-exhausted",
          "Too many requests. Try again in an hour."
        );
      }
    }

    // Generate 6-digit code
    const code = crypto.randomInt(100000, 999999).toString();

    // Store hash + metadata in Firestore
    const codeHash = crypto.createHash("sha256").update(code).digest("hex");
    const sendTimes = existing.exists
      ? [
          ...(existing.data().sendTimes || []).filter(
            (t) => Date.now() - t < 3600000
          ),
          Date.now(),
        ]
      : [Date.now()];

    await docRef.set({
      codeHash,
      expiresAt: Date.now() + CODE_TTL_MS,
      verifyAttempts: 0,
      sendTimes,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send email
    const transporter = getTransporter();
    if (transporter) {
      const fromEmail = process.env.SMTP_FROM_EMAIL || "noreply@ganit-app.com";
      const fromName = process.env.SMTP_FROM_NAME || "Ganit Learning App";

      try {
        await transporter.sendMail({
          from: `"${fromName}" <${fromEmail}>`,
          to: normalizedEmail,
          subject: "Ganit — Parental Consent Verification Code",
          text: `Your verification code is: ${code}\n\nThis code expires in 10 minutes.\n\nIf you did not request this, please ignore this email.`,
          html: `
            <div style="font-family: -apple-system, sans-serif; max-width: 400px; margin: 0 auto; padding: 20px;">
              <h2 style="color: #2563eb;">Ganit Learning App</h2>
              <p>Your parental consent verification code is:</p>
              <div style="font-size: 32px; font-weight: bold; letter-spacing: 8px; text-align: center; padding: 20px; background: #f0f9ff; border-radius: 12px; color: #1e40af;">
                ${code}
              </div>
              <p style="color: #6b7280; font-size: 14px; margin-top: 16px;">This code expires in 10 minutes.</p>
              <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;">
              <p style="color: #9ca3af; font-size: 12px;">All learning data is encrypted on-device and never transmitted.</p>
            </div>
          `,
        });
      } catch (err) {
        console.error("Email send failed:", err.message);
        throw new HttpsError("internal", "Failed to send email. Try again.");
      }
    } else {
      // No SMTP configured — log code for development
      console.log(`[DEV] Verification code for ${normalizedEmail}: ${code}`);
    }

    return { success: true, message: "Verification code sent." };
  }
);

// ─────────────────────────────────────────────
// verifyCode
// Callable from iOS app. Verifies code against
// Firestore-stored hash with rate limiting.
// ─────────────────────────────────────────────

exports.verifyCode = onCall(
  { enforceAppCheck: false },
  async (request) => {
    const { email, code } = request.data;

    if (!email || !code) {
      throw new HttpsError("invalid-argument", "Email and code required.");
    }

    const normalizedEmail = email.trim().toLowerCase();
    const docRef = db.collection("verificationCodes").doc(normalizedEmail);
    const doc = await docRef.get();

    if (!doc.exists) {
      throw new HttpsError(
        "not-found",
        "No verification code found. Request a new one."
      );
    }

    const data = doc.data();

    // Check expiry
    if (Date.now() > data.expiresAt) {
      await docRef.delete();
      throw new HttpsError("deadline-exceeded", "Code expired. Request a new one.");
    }

    // Check attempt limit
    if (data.verifyAttempts >= MAX_VERIFY_ATTEMPTS) {
      await docRef.delete();
      throw new HttpsError(
        "resource-exhausted",
        "Too many failed attempts. Request a new code."
      );
    }

    // Increment attempts
    await docRef.update({
      verifyAttempts: admin.firestore.FieldValue.increment(1),
    });

    // Verify hash
    const inputHash = crypto.createHash("sha256").update(code).digest("hex");
    const isValid = crypto.timingSafeEqual(
      Buffer.from(inputHash),
      Buffer.from(data.codeHash)
    );

    if (isValid) {
      await docRef.delete();
      return { verified: true };
    }

    const remaining = MAX_VERIFY_ATTEMPTS - (data.verifyAttempts + 1);
    throw new HttpsError(
      "permission-denied",
      `Invalid code. ${remaining} attempt${remaining !== 1 ? "s" : ""} remaining.`
    );
  }
);

// ─────────────────────────────────────────────
// deleteUserData (COPPA compliance)
// Callable by authenticated user to delete all
// their data from Firestore.
// ─────────────────────────────────────────────

exports.deleteUserData = onCall(
  { enforceAppCheck: false },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Must be logged in.");
    }

    const uid = request.auth.uid;
    const userRef = db.collection("users").doc(uid);

    // Delete subcollections
    const subcollections = ["sessions", "screeningResults"];
    for (const sub of subcollections) {
      const snapshot = await userRef.collection(sub).get();
      const batch = db.batch();
      snapshot.docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    // Delete user document
    await userRef.delete();

    // Delete Firebase Auth user
    await admin.auth().deleteUser(uid);

    return { success: true, message: "All data deleted." };
  }
);
