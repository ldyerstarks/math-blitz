import SwiftUI

/// The same palette as the web page, so the app feels like the thing he already uses.
enum Theme {
    static let bg = Color(hex: 0x0E1230)
    static let bgBoss = Color(hex: 0x2A0A14)
    static let card = Color(hex: 0x1B2050)
    static let card2 = Color(hex: 0x232A66)
    static let yellow = Color(hex: 0xFFD640)
    static let pink = Color(hex: 0xFF5CA8)
    static let cyan = Color(hex: 0x40DCFF)
    static let green = Color(hex: 0x5CEB8C)
    static let orange = Color(hex: 0xFF963C)
    static let red = Color(hex: 0xFF4D4D)
    static let soft = Color(hex: 0xBEC6EB)

    /// Choice colours A-D, matching the web page's button borders.
    static let choice: [Color] = [cyan, green, orange, pink]

    static func background(boss: Bool) -> LinearGradient {
        LinearGradient(colors: boss ? [bgBoss, Color(hex: 0x4A0D1E)] : [bg, Color(hex: 0x280E46)],
                       startPoint: .top, endPoint: .bottom)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }
}

extension View {
    func cardStyle() -> some View {
        self.padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
