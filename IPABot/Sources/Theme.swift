import SwiftUI
import UIKit

// MARK: - Ledger — IPABot's flat, rule-based design system.
// Single accent, zero corner radius, mono for identifiers, custom glyphs
// instead of SF Symbols. See design_handoff_ledger/README.md for rationale.

private extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((rgb >> 16) & 0xFF) / 255,
                   green: CGFloat((rgb >> 8) & 0xFF) / 255,
                   blue: CGFloat(rgb & 0xFF) / 255,
                   alpha: alpha)
    }
}

private extension Color {
    /// A color that swaps hex values with the active trait collection —
    /// works automatically with .preferredColorScheme(_:) and System mode.
    init(light: UInt32, dark: UInt32) {
        self = Color(UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light) })
    }
}

enum Ledger {
    // MARK: Color
    static let bg = Color(light: 0xF3F2F2, dark: 0x161413)
    static let surface = Color(light: 0xEAE9E9, dark: 0x201E1D)
    static let surface2 = Color(light: 0xFFFFFF, dark: 0x2A2827)
    static let text = Color(light: 0x201E1D, dark: 0xF8F4F4)
    static let textSecondary = text.opacity(0.62)
    static let textTertiary = text.opacity(0.42)
    static let divider = text.opacity(0.4)
    static let dividerSoft = text.opacity(0.14)

    static let accent = Color(red: 0xEC / 255, green: 0x30 / 255, blue: 0x13 / 255)
    /// One step past the base — accent-600 reads right on a light ground, accent-400 on dark.
    static let accentPressed = Color(light: 0xDD2B0F, dark: 0xFF9783)

    /// The one non-accent semantic color: service/queue health needs a "good" signal
    /// distinct from the accent, which always means primary-action-or-attention.
    static let ok = Color(red: 0x3F / 255, green: 0x7D / 255, blue: 0x52 / 255)
    static let okBg = Color(light: 0xE8F1EA, dark: 0x18241C)

    // MARK: Type
    // Uses San Francisco at heavy weights to approximate Archivo's geometric
    // grip until the real font is bundled — see README "Swapping in Archivo".
    // Routed through UIFontMetrics so every Ledger.* call scales with
    // Dynamic Type instead of staying pinned to its literal point size.
    static func heading(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        scaledFont(size: size, weight: weight)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        scaledFont(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        scaledFont(size: size, weight: weight, monospaced: true)
    }

    private static func scaledFont(size: CGFloat, weight: Font.Weight, monospaced: Bool = false) -> Font {
        let uiWeight = uiFontWeight(for: weight)
        let base = monospaced
            ? UIFont.monospacedSystemFont(ofSize: size, weight: uiWeight)
            : UIFont.systemFont(ofSize: size, weight: uiWeight)
        return Font(UIFontMetrics.default.scaledFont(for: base))
    }

    private static func uiFontWeight(for weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .black: return .black
        case .heavy: return .heavy
        case .bold: return .bold
        case .semibold: return .semibold
        case .medium: return .medium
        case .regular: return .regular
        case .light: return .light
        case .thin: return .thin
        case .ultraLight: return .ultraLight
        default: return .regular
        }
    }

    // MARK: Global chrome
    /// Reskins UINavigationBar/UITabBar app-wide. Call once from IPABotApp.init().
    static func configureAppearance() {
        let bgColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0x161413) : UIColor(rgb: 0xF3F2F2) }
        let textColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(rgb: 0xF8F4F4) : UIColor(rgb: 0x201E1D) }
        let shadowColor = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: 0xF8F4F4).withAlphaComponent(0.16)
            : UIColor(rgb: 0x201E1D).withAlphaComponent(0.14)
        }
        let inactiveColor = UIColor { $0.userInterfaceStyle == .dark
            ? UIColor(rgb: 0xF8F4F4).withAlphaComponent(0.42)
            : UIColor(rgb: 0x201E1D).withAlphaComponent(0.42)
        }
        let accentColor = UIColor(rgb: 0xEC3013)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = bgColor
        nav.shadowColor = shadowColor
        nav.titleTextAttributes = [.foregroundColor: textColor, .font: UIFont.systemFont(ofSize: 20, weight: .heavy)]
        nav.largeTitleTextAttributes = [.foregroundColor: textColor, .font: UIFont.systemFont(ofSize: 30, weight: .heavy)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = accentColor

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = bgColor
        tab.shadowColor = shadowColor
        for itemAppearance in [tab.stackedLayoutAppearance, tab.inlineLayoutAppearance, tab.compactInlineLayoutAppearance] {
            itemAppearance.normal.iconColor = inactiveColor
            itemAppearance.normal.titleTextAttributes = [.foregroundColor: inactiveColor, .font: UIFont.systemFont(ofSize: 9, weight: .bold)]
            itemAppearance.selected.iconColor = accentColor
            itemAppearance.selected.titleTextAttributes = [.foregroundColor: accentColor, .font: UIFont.systemFont(ofSize: 9, weight: .bold)]
        }
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        UITableView.appearance().backgroundColor = .clear
    }
}

extension View {
    /// Ledger's flat ground, replacing the default grouped/system background.
    func ledgerBackground() -> some View {
        self.scrollContentBackground(.hidden).background(Ledger.bg)
    }
}

// MARK: - Buttons

struct LedgerPrimaryButtonStyle: ButtonStyle {
    var background: Color = Ledger.accent
    var foreground: Color = .white
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Ledger.heading(13, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundColor(foreground)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(background.opacity(configuration.isPressed ? 0.82 : 1))
    }
}

struct LedgerOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Ledger.heading(13, weight: .bold))
            .textCase(.uppercase)
            .tracking(0.4)
            .foregroundColor(Ledger.text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(configuration.isPressed ? Ledger.surface : Color.clear)
            .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
    }
}

/// A square, icon-only action — sign/inject buttons next to a primary bar.
/// `size` is the tappable frame, held to the 44pt HIG minimum by default.
struct LedgerIconButtonStyle: ButtonStyle {
    var size: CGFloat = 44
    var background: Color = .clear
    var pressedBackground: Color = Ledger.surface
    var foreground: Color = Ledger.text
    var border: Color = Ledger.divider
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(foreground)
            .frame(width: size, height: size)
            .background(configuration.isPressed ? pressedBackground : background)
            .overlay(Rectangle().stroke(border, lineWidth: 1))
    }
}

/// Square checkbox replacing iOS's pill Toggle everywhere in the app —
/// the pill shape conflicts with Ledger's zero-radius rule.
struct LedgerCheckbox: View {
    @Binding var isOn: Bool
    var label: String? = nil
    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack {
                Rectangle().fill(isOn ? Ledger.accent : Color.clear)
                Rectangle().stroke(isOn ? Color.clear : Ledger.divider, lineWidth: 1.5)
                if isOn { Glyph(.check, size: 11, color: .white) }
            }
            .frame(width: 18, height: 18)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "")
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

struct LedgerToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var body: some View {
        HStack {
            Text(label).font(Ledger.body(14)).foregroundColor(Ledger.text).accessibilityHidden(true)
            Spacer()
            LedgerCheckbox(isOn: $isOn, label: label)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
    }
}

struct LedgerStatusDot: View {
    var ok: Bool
    var body: some View {
        Rectangle().fill(ok ? Ledger.ok : Ledger.accent).frame(width: 8, height: 8)
    }
}

struct LedgerSectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Ledger.heading(11, weight: .bold))
            .tracking(1.1)
            .foregroundColor(Ledger.textTertiary)
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A flush key/value line for detail screens (About, Diagnostics, Settings).
struct LedgerKeyValueRow: View {
    let key: String
    let value: String
    var valueIsMono: Bool = true
    var body: some View {
        HStack {
            Text(key).font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
            Spacer()
            Text(value).font(valueIsMono ? Ledger.mono(12) : Ledger.body(13)).foregroundColor(Ledger.text)
        }
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
    }
}

// MARK: - Glyphs
// A small hand-drawn line-icon set covering concepts SF Symbols renders
// generically or not at all (vault, sniper, alias, watch, inject). 24pt
// canvas, 1.75pt stroke at that size, square caps/joins, no fills except
// the tiny radar dot. See README "Glyph set" for the full list + rationale.

enum GlyphName {
    case search, star, eye, sign, inject, unlock, vault, radar, tray, note,
         pin, pulse, gear, seal, plus, chevronRight, chevronLeft, download,
         share, refresh, check, xmark
}

struct GlyphShape: Shape {
    let name: GlyphName

    func path(in r: CGRect) -> Path {
        let s = min(r.width, r.height) / 24
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * s, y: r.minY + y * s) }
        var p = Path()

        switch name {
        case .search:
            p.addEllipse(in: CGRect(x: r.minX + 3.5 * s, y: r.minY + 3.5 * s, width: 13 * s, height: 13 * s))
            p.move(to: pt(15, 15)); p.addLine(to: pt(20.5, 20.5))
        case .star:
            p.move(to: pt(12, 3)); p.addLine(to: pt(19, 12)); p.addLine(to: pt(12, 21)); p.addLine(to: pt(5, 12)); p.closeSubpath()
        case .eye:
            p.move(to: pt(2, 12)); p.addLine(to: pt(7, 6)); p.addLine(to: pt(17, 6)); p.addLine(to: pt(22, 12))
            p.addLine(to: pt(17, 18)); p.addLine(to: pt(7, 18)); p.closeSubpath()
            p.addEllipse(in: CGRect(x: r.minX + 9.5 * s, y: r.minY + 9.5 * s, width: 5 * s, height: 5 * s))
        case .sign:
            p.move(to: pt(20, 4)); p.addLine(to: pt(10, 14)); p.addLine(to: pt(14, 18)); p.closeSubpath()
            p.move(to: pt(4, 20)); p.addLine(to: pt(10, 14))
        case .inject:
            p.addRect(CGRect(x: r.minX + 5 * s, y: r.minY + 5 * s, width: 14 * s, height: 14 * s))
            for x: CGFloat in [9, 12, 15] { p.move(to: pt(x, 8)); p.addLine(to: pt(x, 16)) }
        case .unlock:
            p.addRect(CGRect(x: r.minX + 6 * s, y: r.minY + 11 * s, width: 12 * s, height: 9 * s))
            p.move(to: pt(9, 11)); p.addLine(to: pt(9, 7))
            p.addArc(center: pt(12, 7), radius: 3 * s, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: pt(15, 9))
        case .vault:
            p.addRect(CGRect(x: r.minX + 3 * s, y: r.minY + 6 * s, width: 18 * s, height: 4 * s))
            p.addRect(CGRect(x: r.minX + 4 * s, y: r.minY + 10 * s, width: 16 * s, height: 9 * s))
            p.move(to: pt(10, 14.5)); p.addLine(to: pt(14, 14.5))
        case .radar:
            p.addEllipse(in: CGRect(x: r.minX + 3 * s, y: r.minY + 3 * s, width: 18 * s, height: 18 * s))
            p.addEllipse(in: CGRect(x: r.minX + 7 * s, y: r.minY + 7 * s, width: 10 * s, height: 10 * s))
            p.addEllipse(in: CGRect(x: r.minX + 10.8 * s, y: r.minY + 10.8 * s, width: 2.4 * s, height: 2.4 * s))
            p.move(to: pt(12, 0.5)); p.addLine(to: pt(12, 3))
            p.move(to: pt(12, 21)); p.addLine(to: pt(12, 23.5))
            p.move(to: pt(0.5, 12)); p.addLine(to: pt(3, 12))
            p.move(to: pt(21, 12)); p.addLine(to: pt(23.5, 12))
        case .tray:
            p.move(to: pt(4, 8)); p.addLine(to: pt(9, 8)); p.addLine(to: pt(10.5, 11)); p.addLine(to: pt(13.5, 11))
            p.addLine(to: pt(15, 8)); p.addLine(to: pt(20, 8)); p.addLine(to: pt(20, 18)); p.addLine(to: pt(4, 18)); p.closeSubpath()
        case .note:
            p.addRect(CGRect(x: r.minX + 5 * s, y: r.minY + 3 * s, width: 14 * s, height: 18 * s))
            for y: CGFloat in [8, 12, 16] {
                p.move(to: pt(7.5, y)); p.addLine(to: pt(y == 16 ? 13 : 16.5, y))
            }
        case .pin:
            p.move(to: pt(12, 2)); p.addLine(to: pt(18, 9)); p.addLine(to: pt(12, 22)); p.addLine(to: pt(6, 9)); p.closeSubpath()
        case .pulse:
            p.move(to: pt(2, 12)); p.addLine(to: pt(7, 12)); p.addLine(to: pt(9, 5)); p.addLine(to: pt(13, 19)); p.addLine(to: pt(16, 12)); p.addLine(to: pt(22, 12))
        case .gear:
            p.move(to: pt(12, 2)); p.addLine(to: pt(20, 7)); p.addLine(to: pt(20, 17)); p.addLine(to: pt(12, 22)); p.addLine(to: pt(4, 17)); p.addLine(to: pt(4, 7)); p.closeSubpath()
            p.addEllipse(in: CGRect(x: r.minX + 8.5 * s, y: r.minY + 8.5 * s, width: 7 * s, height: 7 * s))
        case .seal:
            p.move(to: pt(12, 2)); p.addLine(to: pt(20, 7)); p.addLine(to: pt(20, 17)); p.addLine(to: pt(12, 22)); p.addLine(to: pt(4, 17)); p.addLine(to: pt(4, 7)); p.closeSubpath()
            p.move(to: pt(8, 12)); p.addLine(to: pt(11, 15)); p.addLine(to: pt(16, 9))
        case .plus:
            p.move(to: pt(12, 5)); p.addLine(to: pt(12, 19))
            p.move(to: pt(5, 12)); p.addLine(to: pt(19, 12))
        case .chevronRight:
            p.move(to: pt(9, 5)); p.addLine(to: pt(16, 12)); p.addLine(to: pt(9, 19))
        case .chevronLeft:
            p.move(to: pt(15, 4)); p.addLine(to: pt(7, 12)); p.addLine(to: pt(15, 20))
        case .download:
            p.move(to: pt(12, 3)); p.addLine(to: pt(12, 14))
            p.move(to: pt(7, 10)); p.addLine(to: pt(12, 15)); p.addLine(to: pt(17, 10))
            p.move(to: pt(5, 19)); p.addLine(to: pt(19, 19))
        case .share:
            p.move(to: pt(12, 15)); p.addLine(to: pt(12, 4))
            p.move(to: pt(8, 8)); p.addLine(to: pt(12, 4)); p.addLine(to: pt(16, 8))
            p.move(to: pt(5, 13)); p.addLine(to: pt(5, 20)); p.addLine(to: pt(19, 20)); p.addLine(to: pt(19, 13))
        case .refresh:
            p.addArc(center: pt(12, 12), radius: 8 * s, startAngle: .degrees(-40), endAngle: .degrees(200), clockwise: false)
            p.move(to: pt(18, 3)); p.addLine(to: pt(18, 8)); p.addLine(to: pt(13, 8))
        case .check:
            p.move(to: pt(4, 12)); p.addLine(to: pt(9, 17)); p.addLine(to: pt(20, 6))
        case .xmark:
            p.move(to: pt(5, 5)); p.addLine(to: pt(19, 19))
            p.move(to: pt(19, 5)); p.addLine(to: pt(5, 19))
        }
        return p
    }
}

struct Glyph: View {
    let name: GlyphName
    var size: CGFloat = 20
    var color: Color = Ledger.text

    init(_ name: GlyphName, size: CGFloat = 20, color: Color = Ledger.text) {
        self.name = name; self.size = size; self.color = color
    }

    var body: some View {
        ZStack {
            GlyphShape(name: name)
                .stroke(style: StrokeStyle(lineWidth: max(1.1, size * 1.75 / 24), lineCap: .square, lineJoin: .miter))
            if name == .radar {
                Circle().frame(width: size * 2.4 / 24, height: size * 2.4 / 24)
            }
        }
        .foregroundColor(color)
        .frame(width: size, height: size)
    }
}
