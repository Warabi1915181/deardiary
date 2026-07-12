import SwiftUI

struct Card<Content: View>: View {
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
        // Paper on a desk: warm-tinted shadow, never neutral black.
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color("Surface"))
          .shadow(color: Color(red: 0.45, green: 0.3, blue: 0.25).opacity(0.1), radius: 6, x: 0, y: 3)
      )
  }
}
