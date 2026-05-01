import SwiftUI

struct AnniversaryCard: View {
  var numberOfDays: Int

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          Image(systemName: "heart.fill")
            .foregroundColor(.red)
            .font(.system(size: 16))
          Text("Our Anniversary")
            .fontWeight(.semibold)
        }
        Text("\(numberOfDays)")
        .font(.fancy(size: 38))
        .fontWeight(.bold)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 32)
      .padding(.horizontal, 16)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(Color("Backdrop"))
      )
    }
  }
}

struct HomeView: View {
  @SceneStorage("HomeView.datingStartDay") private var datingStartDay: Date?
  @State private var isShowingStartDayModal = false

  private var datingStartDayBinding: Binding<Date> {
    Binding(
      get: { datingStartDay ?? Date() },
      set: {
        datingStartDay = $0
        isShowingStartDayModal = false
      }
    )
  }

  var numberOfDays: Int {
    guard let startDay = datingStartDay else { return 0 }
    return Calendar.current.dateComponents([.day], from: startDay, to: Date()).day ?? 0
  }

  var body: some View {
    ZStack {
      Color("Backdrop").ignoresSafeArea()
      VStack(spacing: 16) {
        AnniversaryCard(numberOfDays: numberOfDays)
        Button("Set Dating Start Day") {
          isShowingStartDayModal = true
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical)
      .sheet(isPresented: $isShowingStartDayModal) {
        NavigationStack {
          DatePicker(
            "Dating Start Day",
            selection: datingStartDayBinding,
            displayedComponents: [.date]
          )
          .datePickerStyle(.graphical)
          .padding()
          .navigationTitle("Dating Start Day")
        }
      }
    }
  }
}
