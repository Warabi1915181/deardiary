import Foundation

/// Everything Home shows, resolved once by `HomeView` so the layout below it
/// only has to arrange — no store reads scattered through the page.
struct HomeContent {
  var anniversaryDate: Date
  var daysTogether: Int
  var daysUntilAnniversary: Int
  var latestEntry: DiaryEntry?
  var latestPhotoURL: URL?
  var milestone: HomeMilestone?
  var resurfaced: ResurfacedMemory.Pick?
  var ideasWaiting: Int

  var anniversaryLine: String {
    let formattedDate = anniversaryDate.formatted(.dateTime.month(.abbreviated).day())
    switch daysUntilAnniversary {
    case 0: return "\(formattedDate) · today"
    case 1: return "\(formattedDate) · tomorrow"
    default: return "\(formattedDate) · \(daysUntilAnniversary) days away"
    }
  }
}

struct HomeMilestone {
  var icon: String
  var title: String
  var date: Date
  var daysUntil: Int

  var isHeart: Bool { icon.hasPrefix("heart") }

  /// On a small note there is only room for one line, so it leads with the
  /// relative distance — how soon matters more than which date.
  var relativeLine: String {
    switch daysUntil {
    case ..<0: return date.formatted(date: .abbreviated, time: .omitted)
    case 0: return "Today"
    case 1: return "Tomorrow"
    default: return "In \(daysUntil) days"
    }
  }
}

/// The gentle greeting DESIGN.md asks Home to open with. It reads the hour,
/// not the scene: Candlelight can arrive at four in the afternoon in winter.
enum HomeGreetingText {
  static func greeting(at date: Date = Date(), calendar: Calendar = .current) -> String {
    switch calendar.component(.hour, from: date) {
    case 0 ..< 5: return "Still up"
    case 5 ..< 12: return "Good morning"
    case 12 ..< 18: return "Good afternoon"
    default: return "Good evening"
    }
  }
}
