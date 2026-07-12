import SwiftUI

struct PartnerMergePromptView: View {
  let onMerge: () -> Void
  let onKeepSeparate: () -> Void

  var body: some View {
    VStack(spacing: 24) {
      Image(systemName: "heart.text.square")
        .font(.system(size: 48))
        .foregroundStyle(Color("SageForeground"))

      VStack(spacing: 12) {
        Text("Merge Your Local Diary?")
          .font(.bold(size: 24))
          .foregroundStyle(Color("RomanceForeground"))

        Text("This device already has diary entries and list items. You can merge them into your shared diary or keep them on this device only.")
          .font(.regular(size: 16))
          .foregroundStyle(Color("PlumForeground"))
          .multilineTextAlignment(.center)
      }

      VStack(spacing: 12) {
        Button(action: onMerge) {
          Text("Merge into Shared Diary")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)

        Button(action: onKeepSeparate) {
          Text("Keep Local Data Separate")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
      }
    }
    .padding(24)
    .presentationDetents([.medium])
  }
}

#Preview {
  PartnerMergePromptView(onMerge: {}, onKeepSeparate: {})
}
