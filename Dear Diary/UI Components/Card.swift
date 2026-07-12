import SwiftUI

struct Card<Content: View>: View {
  @Environment(\.colorScheme) private var colorScheme
  var verticalPadding: CGFloat
  var horizontalPadding: CGFloat
  @ViewBuilder var content: Content

  init(
    verticalPadding: CGFloat = 32,
    horizontalPadding: CGFloat = 16,
    @ViewBuilder content: () -> Content
  ) {
    self.verticalPadding = verticalPadding
    self.horizontalPadding = horizontalPadding
    self.content = content()
  }

  var body: some View {
    content
      .frame(maxWidth: .infinity)
      .padding(.vertical, verticalPadding)
      .padding(.horizontal, horizontalPadding)
      .background(
        // Morning: paper on a desk — warm-tinted shadow, never neutral black.
        // Candlelight: shadows retire; depth comes from the lit edge below.
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color("Surface"))
          .shadow(
            color: colorScheme == .dark
              ? .clear
              : Color(red: 0.45, green: 0.3, blue: 0.25).opacity(0.1),
            radius: 6, x: 0, y: 3
          )
      )
      .overlay(
        // Candlelight: the paper's top edge catches the flame — a faint
        // ember rim in place of a shadow. Invisible by Morning.
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                Color("RomanceForeground").opacity(0.22),
                Color("RomanceForeground").opacity(0.03),
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1
          )
          .opacity(colorScheme == .dark ? 1 : 0)
      )
  }
}
