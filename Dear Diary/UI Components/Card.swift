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
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(.white))
          .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.05), radius: 4, x: 0, y: 2)
      )
  }
}
