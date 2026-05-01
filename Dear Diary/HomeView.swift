import SwiftUI

struct AnniversaryCard: View {
  var anniversaryDate: Date
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
        Text("days left")
          .fontWeight(.semibold)
        Text(anniversaryDate.formatted(date: .abbreviated, time: .omitted))
          .font(.regular)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 16)
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

  /// Inclusive bounds; `endDate` is today (same calendar day in local TZ), last selectable instant that day.
  private var dateRange: ClosedRange<Date> {
    let calendar = Calendar.current
    let now = Date()
    let startDate = calendar.date(byAdding: .year, value: -200, to: now) ?? Date.distantPast
    let todayStart = calendar.startOfDay(for: now)
    let endDate =
      calendar.date(bySettingHour: 23, minute: 59, second: 59, of: todayStart) ?? todayStart
    return startDate...endDate
  }

  private var datingStartDayBinding: Binding<Date> {
    Binding(
      get: {
        let raw = datingStartDay ?? Date()
        let bounds = dateRange
        return min(max(raw, bounds.lowerBound), bounds.upperBound)
      },
      set: {
        datingStartDay = $0
        isShowingStartDayModal = false
      }
    )
  }

  private var anniversaryAnchorDay: Date {
    datingStartDay ?? Date()
  }

  /// Next calendar occurrence of anchor month/day (local TZ), inclusive of today.
  private var anniversaryDate: Date {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    let m = calendar.component(.month, from: anniversaryAnchorDay)
    let d = calendar.component(.day, from: anniversaryAnchorDay)
    let year = calendar.component(.year, from: Date())
    var dc = DateComponents(year: year, month: m, day: d)
    guard var candidate = calendar.date(from: dc) else {
      return todayStart
    }
    if calendar.startOfDay(for: candidate) < todayStart {
      dc.year = year + 1
      candidate = calendar.date(from: dc) ?? candidate
    }
    return calendar.startOfDay(for: candidate)
  }

  private var daysUntilAnniversary: Int {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    return calendar.dateComponents([.day], from: todayStart, to: anniversaryDate).day ?? 0
  }

  var body: some View {
    ZStack {
      Color("Backdrop").ignoresSafeArea()
      VStack(spacing: 16) {
        AnniversaryCard(anniversaryDate: anniversaryDate, numberOfDays: daysUntilAnniversary)
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
            in: dateRange,
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
