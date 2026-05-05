import SwiftUI

// MARK: - Colors matching the website palette

extension Color {
    static let ctBackground  = Color(red: 0.961, green: 0.937, blue: 0.902) // #f5efe6
    static let ctPanel       = Color(red: 1.000, green: 0.992, blue: 0.969) // #fffcf7
    static let ctAccent      = Color(red: 0.851, green: 0.435, blue: 0.196) // #d96f32
    static let ctAccentDark  = Color(red: 0.651, green: 0.290, blue: 0.094) // #a64a18
    static let ctText        = Color(red: 0.137, green: 0.090, blue: 0.051) // #23170d
    static let ctMuted       = Color(red: 0.435, green: 0.365, blue: 0.298) // #6f5d4c
    static let ctLine        = Color(red: 0.306, green: 0.224, blue: 0.133).opacity(0.12)
}

// MARK: - Typography

extension Font {
    static func ctSerif(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Georgia", size: size).weight(weight)
    }
    static func ctSerifBold(_ size: CGFloat) -> Font {
        .custom("Georgia", size: size).weight(.bold)
    }
}

// MARK: - View modifiers

struct PanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.ctPanel.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.ctLine, lineWidth: 1))
            .shadow(color: Color(red: 0.275, green: 0.176, blue: 0.086).opacity(0.12), radius: 24, y: 10)
    }
}

struct SmallPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.ctPanel.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.ctLine, lineWidth: 1))
            .shadow(color: Color(red: 0.275, green: 0.176, blue: 0.086).opacity(0.08), radius: 12, y: 4)
    }
}

extension View {
    func ctPanel() -> some View { modifier(PanelStyle()) }
    func ctSmallPanel() -> some View { modifier(SmallPanelStyle()) }
}

// MARK: - Warm gradient background

struct WarmBackground: View {
    var body: some View {
        ZStack {
            Color.ctBackground.ignoresSafeArea()
            GeometryReader { geo in
                // top-left orange glow
                RadialGradient(
                    colors: [Color(red: 1, green: 0.722, blue: 0.490).opacity(0.5), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.6
                )
                .ignoresSafeArea()
                // bottom-right deeper orange glow
                RadialGradient(
                    colors: [Color(red: 0.780, green: 0.361, blue: 0.192).opacity(0.24), .clear],
                    center: .bottomTrailing,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.5
                )
                .ignoresSafeArea()
            }
        }
    }
}

// MARK: - Pill button styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ctSerif(16, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.ctAccent)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ctSerif(16, weight: .bold))
            .foregroundStyle(Color.ctText)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.ctMuted.opacity(0.12))
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

// MARK: - Eyebrow label

struct EyebrowLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.ctSerif(11, weight: .regular))
            .kerning(2.5)
            .foregroundStyle(Color.ctAccentDark)
    }
}

// MARK: - Vitamin / progress bar row

struct VitaminRow: View {
    let name: String
    let percent: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.ctSerif(13))
                .foregroundStyle(Color.ctMuted)
                .frame(width: 80, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.ctAccentDark.opacity(0.12))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.ctAccent)
                        .frame(width: geo.size.width * min(CGFloat(percent) / 100.0, 1.0), height: 6)
                        .animation(.easeOut(duration: 0.4), value: percent)
                }
            }
            .frame(height: 6)
            Text("\(percent)%")
                .font(.ctSerif(13, weight: .bold))
                .foregroundStyle(Color.ctAccentDark)
                .frame(width: 38, alignment: .trailing)
        }
    }
}
