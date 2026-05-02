import SwiftUI

struct DatingSettingsView: View {
  @AppStorage(DatingStartDayStore.appStorageKey) private var datingStartDaySince1970: Double =
    DatingStartDayStore.appStorageDefaultInterval
  @State private var isShowingStartDayModal = false

  private var datingStartDayBinding: Binding<Date> {
    DatingStartDayStore.dateBinding(
      storedInterval: $datingStartDaySince1970,
      onChange: { date in
        isShowingStartDayModal = false
      })
  }

  private var dateRange: ClosedRange<Date> {
    DatingStartDayStore.allowedDateRange()
  }

  private var datingStartDayString: String {
    let date = datingStartDayBinding.wrappedValue
    return date.formatted(date: .abbreviated, time: .omitted)
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
