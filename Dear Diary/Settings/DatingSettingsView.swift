import SwiftUI

struct DatingSettingsView: View {
  @Environment(AppEnvironment.self) private var environment
  @State private var isShowingStartDayModal = false

  private var datingStartDayBinding: Binding<Date> {
    Binding(
      get: { environment.coupleSpaceStore.datingStartDay },
      set: { newValue in
        _ = environment.coupleSpaceStore.setDatingStartDay(newValue)
        isShowingStartDayModal = false
      }
    )
  }

  private var dateRange: ClosedRange<Date> {
    DatingStartDayStore.allowedDateRange()
  }

  private var datingStartDayString: String {
    datingStartDayBinding.wrappedValue.formatted(date: .abbreviated, time: .omitted)
  }

  var body: some View {
    Form {
      Button("Dating Start Day: \(datingStartDayString)") {
        isShowingStartDayModal = true
      }
      .sheet(isPresented: $isShowingStartDayModal) {
        NavigationStack {
          DatePicker(
            "Dating Start Day",
            selection: datingStartDayBinding,
            in: dateRange,
            displayedComponents: [.date]
          )
          .datePickerStyle(.graphical)
          .padding()
          .navigationTitle("Dating Start Day")
        }
      }
    }
    .navigationTitle("Dating Start Day")
    .navigationBarTitleDisplayMode(.inline)
  }
}

#Preview {
  NavigationStack {
    DatingSettingsView()
      .environment(AppEnvironment())
  }
}
