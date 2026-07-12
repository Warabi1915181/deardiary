import SwiftUI

/// A small strip of translucent "washi tape" — the scrapbook cue that holds
/// a photo or note onto the page. Use sparingly: one piece per card at most.
struct WashiTape: View {
  @Environment(\.colorScheme) private var colorScheme
  var angle: Double = -4

  var body: some View {
    Rectangle()
      // Morning: blush paper tape. Candlelight: the tape catches the
      // ember light — translucent, faintly glowing, never muddy brown.
      .fill(
        colorScheme == .dark
          ? Color("RomanceForeground").opacity(0.32)
          : Color("RomanceBackground").opacity(0.85)
      )
      .frame(width: 72, height: 22)
      .overlay(
        Rectangle()
          .stroke(Color("RomanceForeground").opacity(colorScheme == .dark ? 0.35 : 0.12), lineWidth: 1)
      )
      .rotationEffect(.degrees(angle))
      .shadow(
        color: colorScheme == .dark
          ? Color("RomanceForeground").opacity(0.3)
          : Color(red: 0.45, green: 0.3, blue: 0.25).opacity(0.15),
        radius: colorScheme == .dark ? 4 : 2, x: 0, y: 1
      )
  }
}

/// Wraps a photo like a snapshot taped into a scrapbook: white paper border,
/// a hair of rotation, and a piece of tape across the top edge.
struct TapedPhoto<Content: View>: View {
  var angle: Double = 1.2
  @ViewBuilder var content: Content

  var body: some View {
    content
      .padding(6)
      .background(Color("Surface"))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .shadow(color: Color(red: 0.45, green: 0.3, blue: 0.25).opacity(0.18), radius: 4, x: 0, y: 2)
      .rotationEffect(.degrees(angle))
      .overlay(alignment: .top) {
        WashiTape()
          .offset(y: -8)
      }
  }
}

#Preview {
  ZStack {
    Color(.backdrop).ignoresSafeArea()
    TapedPhoto {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color("PlumBackground"))
        .frame(width: 240, height: 160)
    }
  }
}
