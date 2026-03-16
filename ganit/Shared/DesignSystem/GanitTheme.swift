import SwiftUI
import Combine

// MARK: - Ganit Theme

/// Theme coordinator that provides styling based on UserGroup (child vs elderly)
/// and anxiety-friendly mode toggle.
@MainActor
final class GanitTheme: ObservableObject {

    // MARK: - Published State

    @Published var userGroup: UserGroup
    @Published var anxietyFriendlyMode: Bool

    // MARK: - Derived

    var typographyMode: Typography.Mode {
        Typography.Mode(from: userGroup)
    }

    var isElderly: Bool {
        userGroup == .elderly
    }

    // MARK: - Init

    init(userGroup: UserGroup = .child, anxietyFriendlyMode: Bool = false) {
        self.userGroup = userGroup
        self.anxietyFriendlyMode = anxietyFriendlyMode
    }

    // MARK: - Convenience Init from Accommodations

    convenience init(userGroup: UserGroup, accommodations: [Accommodation]) {
        self.init(
            userGroup: userGroup,
            anxietyFriendlyMode: accommodations.contains(.anxietyFriendly)
        )
    }

    // MARK: - Color Accessors

    func correctColor() -> Color {
        if isElderly {
            return AccessibleColors.highContrastCorrect
        }
        return AccessibleColors.correct(anxietyFriendly: anxietyFriendlyMode)
    }

    func incorrectColor() -> Color {
        if isElderly {
            return AccessibleColors.highContrastIncorrect
        }
        return AccessibleColors.incorrect(anxietyFriendly: anxietyFriendlyMode)
    }

    func correctBackground() -> Color {
        if isElderly {
            return AccessibleColors.highContrastCorrect.opacity(0.15)
        }
        return AccessibleColors.correctBackground(anxietyFriendly: anxietyFriendlyMode)
    }

    func incorrectBackground() -> Color {
        if isElderly {
            return AccessibleColors.highContrastIncorrect.opacity(0.15)
        }
        return AccessibleColors.incorrectBackground(anxietyFriendly: anxietyFriendlyMode)
    }

    func hintColor() -> Color {
        AccessibleColors.hint
    }

    func accuracyColor(_ value: Double) -> Color {
        AccessibleColors.accuracy(value, anxietyFriendly: anxietyFriendlyMode)
    }

    // MARK: - Font Accessors

    func largeTitle() -> Font { Typography.largeTitle(mode: typographyMode) }
    func title() -> Font { Typography.title(mode: typographyMode) }
    func headline() -> Font { Typography.headline(mode: typographyMode) }
    func body() -> Font { Typography.body(mode: typographyMode) }
    func question() -> Font { Typography.question(mode: typographyMode) }
    func option() -> Font { Typography.option(mode: typographyMode) }
    func caption() -> Font { Typography.caption(mode: typographyMode) }
    func button() -> Font { Typography.button(mode: typographyMode) }
    func numberDisplay() -> Font { Typography.numberDisplay(mode: typographyMode) }
    func lineSpacing() -> CGFloat { Typography.lineSpacing(mode: typographyMode) }
}

// MARK: - Theme View Modifier

/// Applies the Ganit theme to a view hierarchy via environment.
struct GanitThemeModifier: ViewModifier {
    @ObservedObject var theme: GanitTheme
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environmentObject(theme)
            .tint(AccessibleColors.primaryAccent)
            .background(backgroundColor)
    }

    private var backgroundColor: Color {
        if theme.isElderly {
            return colorScheme == .dark
                ? Color(red: 0.08, green: 0.08, blue: 0.10)
                : AccessibleColors.highContrastBackground
        }
        return AccessibleColors.cardBackground(for: colorScheme).opacity(0.3)
    }
}

extension View {
    /// Applies the Ganit design system theme to the view hierarchy.
    func ganitTheme(_ theme: GanitTheme) -> some View {
        modifier(GanitThemeModifier(theme: theme))
    }
}

// MARK: - Themed Option Button Style

/// A button style for quiz options that uses the theme's anxiety-friendly colors.
struct ThemedOptionButtonStyle: ButtonStyle {
    let isCorrect: Bool?
    let isSelected: Bool
    @ObservedObject var theme: GanitTheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.option())
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }

    private var background: Color {
        guard let isCorrect else {
            // Not yet answered
            return AccessibleColors.cardBackground
        }

        if isCorrect {
            return theme.correctBackground()
        }

        if isSelected {
            return theme.incorrectBackground()
        }

        return AccessibleColors.cardBackground.opacity(0.5)
    }
}

// MARK: - Themed Feedback Icon

/// Shows a check or indicator using anxiety-friendly or standard colors.
struct ThemedFeedbackIcon: View {
    let isCorrect: Bool
    @EnvironmentObject var theme: GanitTheme

    var body: some View {
        Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(isCorrect ? theme.correctColor() : theme.incorrectColor())
            .font(.system(size: theme.isElderly ? 28 : 22))
    }
}
