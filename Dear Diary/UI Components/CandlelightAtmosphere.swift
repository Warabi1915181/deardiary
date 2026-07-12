import SwiftUI

enum BackdropAtmosphere {
  case none
  case candlelightHome
}

struct CandlelightAtmosphere: View {
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    GeometryReader { geometry in
      let longestEdge = max(geometry.size.width, geometry.size.height)

      ZStack {
        Rectangle()
          .fill(
            RadialGradient(
              colors: [
                Color("RomanceForeground").opacity(0.16),
                Color("RomanceForeground").opacity(0.055),
                .clear,
              ],
              center: UnitPoint(x: 0.58, y: 1.08),
              startRadius: 0,
              endRadius: longestEdge * 0.72
            )
          )
          .blendMode(.plusLighter)

        Rectangle()
          .fill(
            RadialGradient(
              colors: [
                .clear,
                .clear,
                Color("Backdrop").opacity(0.48),
              ],
              center: UnitPoint(x: 0.5, y: 0.54),
              startRadius: longestEdge * 0.24,
              endRadius: longestEdge * 0.78
            )
          )
          .blendMode(.multiply)
      }
      .opacity(colorScheme == .dark ? 1 : 0)
    }
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

private struct CandlelightCatchlight: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      .shadow(
        color: Color("RomanceForeground")
          .opacity(colorScheme == .dark ? 0.14 : 0),
        radius: 18,
        x: 0,
        y: 10
      )
  }
}

extension View {
  func candlelightCatchlight() -> some View {
    modifier(CandlelightCatchlight())
  }
}

#Preview("Candlelight Atmosphere") {
  ZStack {
    Color("Backdrop")
    CandlelightAtmosphere()
    VStack(spacing: 16) {
      Card(verticalPadding: 16) {
        Text("Our Anniversary")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      Card(verticalPadding: 16) {
        Text("Latest Memory")
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .candlelightCatchlight()
    }
    .padding(16)
  }
  .preferredColorScheme(.dark)
}
