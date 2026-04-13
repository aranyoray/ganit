import SwiftUI

// MARK: - Accessible Colors

/// Anxiety-friendly, colorblind-safe color palette for Ganit.
/// Replaces harsh red/green with soft teal/amber for correct/wrong feedback.
/// Supports high contrast mode for elderly users and dark mode.
enum AccessibleColors {

    // MARK: - Feedback Colors (Anxiety-Friendly)

    /// Soft teal/blue for correct answers instead of harsh green.
    static let correctSoft = Color("CorrectSoft", bundle: nil)
    static let correctSoftFallback = Color(red: 0.42, green: 0.78, blue: 0.74) // #6BC7BD

    /// Soft amber/peach for wrong answers instead of harsh red.
    static let incorrectSoft = Color("IncorrectSoft", bundle: nil)
    static let incorrectSoftFallback = Color(red: 0.95, green: 0.76, blue: 0.47) // #F2C278

    /// Correct answer (resolved based on anxiety-friendly mode).
    static func correct(anxietyFriendly: Bool) -> Color {
        anxietyFriendly ? correctSoftFallback : standardCorrect
    }

    /// Incorrect answer (resolved based on anxiety-friendly mode).
    static func incorrect(anxietyFriendly: Bool) -> Color {
        anxietyFriendly ? incorrectSoftFallback : standardIncorrect
    }

    // MARK: - Standard Feedback Colors

    /// Standard correct: accessible green (not pure green, colorblind-safe).
    static let standardCorrect = Color(red: 0.20, green: 0.65, blue: 0.45) // #33A673

    /// Standard incorrect: accessible warm red (not pure red, colorblind-safe).
    static let standardIncorrect = Color(red: 0.85, green: 0.35, blue: 0.30) // #D9594D

    // MARK: - Background Tints

    /// Correct answer background tint.
    static func correctBackground(anxietyFriendly: Bool) -> Color {
        correct(anxietyFriendly: anxietyFriendly).opacity(0.15)
    }

    /// Incorrect answer background tint.
    static func incorrectBackground(anxietyFriendly: Bool) -> Color {
        incorrect(anxietyFriendly: anxietyFriendly).opacity(0.15)
    }

    // MARK: - Neutral UI Colors

    /// Primary interactive element color.
    static let primaryAccent = Color(red: 0.30, green: 0.55, blue: 0.85) // #4D8CD9

    /// Secondary/muted accent.
    static let secondaryAccent = Color(red: 0.55, green: 0.65, blue: 0.75) // #8CA6BF

    /// Hint/tip color (soft orange, not harsh).
    static let hint = Color(red: 0.90, green: 0.70, blue: 0.40) // #E6B366

    /// Neutral card/option background.
    static let cardBackground = Color(red: 0.96, green: 0.96, blue: 0.97) // #F5F5F8

    /// Neutral card background for dark mode.
    static let cardBackgroundDark = Color(red: 0.15, green: 0.15, blue: 0.18) // #26262E

    // MARK: - High Contrast (Elderly Mode)

    /// High contrast text on light backgrounds.
    static let highContrastText = Color(red: 0.10, green: 0.10, blue: 0.12)

    /// High contrast background.
    static let highContrastBackground = Color(red: 0.98, green: 0.98, blue: 0.99)

    /// High contrast correct.
    static let highContrastCorrect = Color(red: 0.0, green: 0.50, blue: 0.60) // Deep teal

    /// High contrast incorrect.
    static let highContrastIncorrect = Color(red: 0.80, green: 0.50, blue: 0.10) // Deep amber

    // MARK: - Colorblind-Safe Palette

    /// A palette that avoids pure red/green distinctions.
    /// Uses blue, orange, and teal as primary differentiators.
    static let colorblindSafe: [Color] = [
        Color(red: 0.30, green: 0.55, blue: 0.85), // Blue
        Color(red: 0.90, green: 0.60, blue: 0.20), // Orange
        Color(red: 0.42, green: 0.78, blue: 0.74), // Teal
        Color(red: 0.70, green: 0.40, blue: 0.75), // Purple
        Color(red: 0.95, green: 0.76, blue: 0.47), // Amber
        Color(red: 0.55, green: 0.65, blue: 0.75), // Slate
    ]

    // MARK: - Adaptive Card Background

    /// Returns the appropriate card background for the current color scheme.
    static func cardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? cardBackgroundDark : cardBackground
    }

    // MARK: - Accuracy Indicator

    /// Accuracy badge color (anxiety-friendly uses blue spectrum instead of red/green).
    static func accuracy(_ value: Double, anxietyFriendly: Bool) -> Color {
        if anxietyFriendly {
            // Blue spectrum: light blue (low) -> deep blue (high)
            if value >= 0.75 { return Color(red: 0.20, green: 0.45, blue: 0.75) }
            if value >= 0.50 { return Color(red: 0.40, green: 0.60, blue: 0.80) }
            return Color(red: 0.60, green: 0.70, blue: 0.85)
        } else {
            if value >= 0.75 { return standardCorrect }
            if value >= 0.50 { return hint }
            return standardIncorrect
        }
    }
}
