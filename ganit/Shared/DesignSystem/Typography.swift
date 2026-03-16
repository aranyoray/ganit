import SwiftUI

// MARK: - Typography

/// Ganit typography system with user-group-aware sizing.
/// Child mode: playful, medium sizes.
/// Elderly mode: larger base size (18pt minimum), higher weight for readability.
/// Full Dynamic Type support for accessibility scaling.
enum Typography {

    // MARK: - User Group

    enum Mode {
        case child
        case elderly

        init(from userGroup: UserGroup) {
            switch userGroup {
            case .child:   self = .child
            case .elderly: self = .elderly
            }
        }
    }

    // MARK: - Semantic Text Styles

    /// Large title (screen headers).
    static func largeTitle(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 28, weight: .bold, design: .rounded)
        case .elderly:
            return .system(size: 34, weight: .bold, design: .default)
        }
    }

    /// Title (section headers).
    static func title(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 22, weight: .semibold, design: .rounded)
        case .elderly:
            return .system(size: 28, weight: .bold, design: .default)
        }
    }

    /// Headline (card titles, emphasis).
    static func headline(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 18, weight: .semibold, design: .rounded)
        case .elderly:
            return .system(size: 24, weight: .semibold, design: .default)
        }
    }

    /// Body text (primary content).
    static func body(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 16, weight: .regular, design: .rounded)
        case .elderly:
            return .system(size: 20, weight: .regular, design: .default)
        }
    }

    /// Question text (larger, prominent).
    static func question(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 24, weight: .bold, design: .rounded)
        case .elderly:
            return .system(size: 30, weight: .bold, design: .default)
        }
    }

    /// Option text (quiz answer choices).
    static func option(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 18, weight: .medium, design: .rounded)
        case .elderly:
            return .system(size: 22, weight: .medium, design: .default)
        }
    }

    /// Caption text (secondary info).
    static func caption(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 13, weight: .regular, design: .rounded)
        case .elderly:
            return .system(size: 18, weight: .regular, design: .default)
        }
    }

    /// Button label text.
    static func button(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 17, weight: .semibold, design: .rounded)
        case .elderly:
            return .system(size: 22, weight: .semibold, design: .default)
        }
    }

    /// Number display (large numerals for counting/math).
    static func numberDisplay(mode: Mode) -> Font {
        switch mode {
        case .child:
            return .system(size: 48, weight: .bold, design: .rounded)
        case .elderly:
            return .system(size: 56, weight: .bold, design: .monospaced)
        }
    }

    // MARK: - Minimum Size Enforcement

    /// Returns the minimum font size for a given mode.
    /// Elderly mode enforces 18pt minimum per accessibility guidelines.
    static func minimumSize(mode: Mode) -> CGFloat {
        switch mode {
        case .child:   return 13
        case .elderly: return 18
        }
    }

    // MARK: - Line Spacing

    /// Appropriate line spacing for readability.
    static func lineSpacing(mode: Mode) -> CGFloat {
        switch mode {
        case .child:   return 4
        case .elderly: return 6
        }
    }
}

// MARK: - View Modifiers

/// Applies typography mode to a Text view with appropriate line spacing.
struct TypographyModifier: ViewModifier {
    let font: Font
    let mode: Typography.Mode

    func body(content: Content) -> some View {
        content
            .font(font)
            .lineSpacing(Typography.lineSpacing(mode: mode))
    }
}

extension View {
    /// Applies Ganit typography with user-group-aware sizing and spacing.
    func ganitFont(_ font: Font, mode: Typography.Mode) -> some View {
        modifier(TypographyModifier(font: font, mode: mode))
    }
}

// MARK: - Dynamic Type Scaling

/// Ensures elderly mode fonts scale with Dynamic Type but never below the minimum.
struct ScaledTypography {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let mode: Typography.Mode

    /// Returns a scaled size that respects the minimum for the mode.
    func scaled(_ baseSize: CGFloat) -> CGFloat {
        let minimum = Typography.minimumSize(mode: mode)
        let scaleFactor = dynamicTypeScaleFactor
        return max(minimum, baseSize * scaleFactor)
    }

    private var dynamicTypeScaleFactor: CGFloat {
        switch dynamicTypeSize {
        case .xSmall:         return 0.85
        case .small:          return 0.90
        case .medium:         return 0.95
        case .large:          return 1.00
        case .xLarge:         return 1.10
        case .xxLarge:        return 1.20
        case .xxxLarge:       return 1.30
        case .accessibility1: return 1.40
        case .accessibility2: return 1.55
        case .accessibility3: return 1.70
        case .accessibility4: return 1.85
        case .accessibility5: return 2.00
        @unknown default:     return 1.00
        }
    }
}
