import SwiftUI
import UIKit

/// The count of days together is the card's focal number — it only ever grows.
/// The anniversary countdown signs it underneath. No heading label: the number
/// and its words are one handwritten sentence.
struct UsCard: View {
  @Environment(\.colorScheme) private var colorScheme
  var anniversaryDate: Date
  var daysTogether: Int
  var daysUntilAnniversary: Int

  private var anniversaryLine: String {
    let formattedDate = anniversaryDate.formatted(.dateTime.month(.abbreviated).day())
    switch daysUntilAnniversary {
    case 0: return "\(formattedDate) · today"
    case 1: return "\(formattedDate) · tomorrow"
    default: return "\(formattedDate) · \(daysUntilAnniversary) days away"
    }
  }

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(daysTogether.formatted(.number.grouping(.automatic)))
            .font(.displayNumber)
          Text("days together")
            .font(.bodyEmphasis)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .allowsTightening(true)
        }

        HStack(spacing: 4) {
          Image(systemName: "heart.fill")
            .font(.system(size: 10))
            .foregroundColor(Color("HeartRose"))
            // Candlelight: the rose jewel glows faintly in the dark.
            .shadow(
              color: Color("HeartRose").opacity(colorScheme == .dark ? 0.55 : 0),
              radius: 4
            )
          Text(anniversaryLine)
            .font(.metadata)
            .foregroundStyle(Color("InkMuted"))
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

struct LatestMemoryCard: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  let entry: DiaryEntry
  let photoURL: URL?

  private var headingFont: Font {
    dynamicTypeSize.isAccessibilitySize ? .cardTitleCompact : .cardTitle
  }

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .top, spacing: 4) {
          Image(systemName: "book.closed")
            .foregroundStyle(Color("RomanceForeground"))
          Text(handwritten: "Latest Memory")
            .font(headingFont)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
        }

        Text(handwritten: entry.title)
          .font(.entryTitle)
          .foregroundStyle(Color("RomanceForeground"))

        if !entry.body.isEmpty {
          Text(entry.body)
            .font(.body)
            .foregroundStyle(Color("RomanceForeground"))
            .lineLimit(3)
        }

        if let photoURL, let image = UIImage(contentsOfFile: photoURL.path) {
          TapedPhoto {
            Image(uiImage: image)
              .resizable()
              .scaledToFill()
              .frame(maxWidth: .infinity)
              .frame(height: 160)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          }
          .padding(.top, 8)
        }

        Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
          .font(.metadata)
          .foregroundStyle(Color("InkMuted"))
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .candlelightCatchlight()
  }
}

struct NextMilestoneCard: View {
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var icon: String
  var title: String
  var date: Date
  var daysUntil: Int

  private var headingFont: Font {
    dynamicTypeSize.isAccessibilitySize ? .cardTitleCompact : .cardTitle
  }

  private var isHeart: Bool {
    icon.hasPrefix("heart")
  }

  private var dateLine: String {
    let formattedDate = date.formatted(date: .abbreviated, time: .omitted)
    switch daysUntil {
    case ..<0: return formattedDate
    case 0: return "\(formattedDate) · Today"
    case 1: return "\(formattedDate) · Tomorrow"
    default: return "\(formattedDate) · in \(daysUntil) days"
    }
  }

  var body: some View {
    Card(verticalPadding: 16) {
      HStack(alignment: .top, spacing: 12) {
        VStack(alignment: .leading, spacing: 8) {
          HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
              .foregroundStyle(isHeart ? Color("HeartRose") : Color("RomanceForeground"))
              .font(.system(size: 16))
            Text(handwritten: "Something to look forward to")
              .font(headingFont)
              .lineLimit(2)
              .minimumScaleFactor(0.6)
              .allowsTightening(true)
          }
          Text(handwritten: title)
            .font(.entryTitle)
            .foregroundStyle(Color("RomanceForeground"))
          Text(dateLine)
            .font(.metadata)
            .foregroundStyle(Color("InkMuted"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)

        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color("InkMuted"))
          .padding(.top, 4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

/// Home's card stack ends at the milestone; what follows is margin. A ruled
/// aside for the resurfaced memory, and one quiet line for waiting ideas —
/// neither is a Card, so neither competes with the stack above.
struct ResurfacedMemoryWhisper: View {
  let pick: ResurfacedMemory.Pick

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(ResurfacedMemory.heading(for: pick))
        .font(.metadata)
        .foregroundStyle(Color("InkMuted"))
      Text(handwritten: pick.entry.title)
        .font(.regularItalic(size: 24))
        .foregroundStyle(Color("RomanceForeground"))
        .multilineTextAlignment(.leading)
      Text(pick.entry.entryDate.formatted(date: .abbreviated, time: .omitted))
        .font(.metadata)
        .foregroundStyle(Color("InkMuted"))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.leading, 12)
    .overlay(alignment: .leading) {
      // True 1px hairline — the documented exception to the 4pt grid.
      Rectangle()
        .fill(Color("PlumForeground").opacity(0.35))
        .frame(width: 1)
    }
  }
}

struct IdeasWaitingRow: View {
  let count: Int

  private var label: String {
    count == 1 ? "1 idea waiting" : "\(count) ideas waiting"
  }

  var body: some View {
    HStack(spacing: 8) {
      Text(label)
        .font(.body)
        .foregroundStyle(Color("InkMuted"))
      Image(systemName: "chevron.right")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(Color("InkMuted"))
      Spacer(minLength: 0)
    }
    .frame(height: 44)
    .contentShape(Rectangle())
  }
}

struct HomeView: View {
  @Environment(AppEnvironment.self) private var environment
  @Binding var selectedTab: AppTab

  private var anniversaryAnchorDay: Date {
    environment.coupleSpaceStore.datingStartDay
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

  private var daysTogether: Int {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: anniversaryAnchorDay)
    let todayStart = calendar.startOfDay(for: Date())
    return max(calendar.dateComponents([.day], from: start, to: todayStart).day ?? 0, 0)
  }

  private struct NextMilestoneCandidate {
    var icon: String
    var title: String
    var date: Date
  }

  /// The single soonest upcoming moment worth surfacing: whichever of the
  /// nearest user-created milestone or the auto-derived special-number
  /// moment lands first. Never both, never a list — see AutoMilestone.swift.
  private var nextMilestoneCandidate: NextMilestoneCandidate? {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    let milestoneStore = environment.milestoneStore

    let nearestUserMilestone = milestoneStore.milestones
      .map { ($0, milestoneStore.nextOccurrence(of: $0)) }
      .filter { calendar.startOfDay(for: $0.1) >= todayStart }
      .min { $0.1 < $1.1 }

    let autoMoment = AutoMilestone.nextMoment(datingStartDay: anniversaryAnchorDay)

    switch (nearestUserMilestone, autoMoment) {
    case let (userMilestone?, auto?):
      if userMilestone.1 <= auto.date {
        return NextMilestoneCandidate(icon: userMilestone.0.icon, title: userMilestone.0.title, date: userMilestone.1)
      } else {
        return NextMilestoneCandidate(icon: "sparkles", title: auto.label, date: auto.date)
      }
    case let (userMilestone?, nil):
      return NextMilestoneCandidate(icon: userMilestone.0.icon, title: userMilestone.0.title, date: userMilestone.1)
    case let (nil, auto?):
      return NextMilestoneCandidate(icon: "sparkles", title: auto.label, date: auto.date)
    case (nil, nil):
      return nil
    }
  }

  private var resurfacedPick: ResurfacedMemory.Pick? {
    ResurfacedMemory.pick(from: environment.diaryStore.entries)
  }

  private func daysUntil(_ date: Date) -> Int {
    let calendar = Calendar.current
    let todayStart = calendar.startOfDay(for: Date())
    return calendar.dateComponents([.day], from: todayStart, to: calendar.startOfDay(for: date)).day ?? 0
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        UsCard(
          anniversaryDate: anniversaryDate,
          daysTogether: daysTogether,
          daysUntilAnniversary: daysUntilAnniversary
        )
        // No memory yet: Us becomes the focal surface and
        // catches the flame in Latest Memory's place.
        .candlelightCatchlight(environment.diaryStore.latestEntry == nil)
        if let latestEntry = environment.diaryStore.latestEntry {
          NavigationLink {
            DiaryEntryDetailView(store: environment.diaryStore, entryID: latestEntry.id)
          } label: {
            LatestMemoryCard(
              entry: latestEntry,
              photoURL: latestEntry.photos.first.map { environment.diaryStore.photoURL(for: $0) }
            )
          }
          .buttonStyle(.plain)
        }
        if let candidate = nextMilestoneCandidate {
          NavigationLink {
            MilestonesView(store: environment.milestoneStore, diaryStore: environment.diaryStore)
          } label: {
            NextMilestoneCard(
              icon: candidate.icon,
              title: candidate.title,
              date: candidate.date,
              daysUntil: daysUntil(candidate.date)
            )
          }
          .buttonStyle(.plain)
        }

        // The quiet tail. Each half appears only once it has something true
        // to say — on a new couple's first day, Home is still one card.
        VStack(alignment: .leading, spacing: 16) {
          if let pick = resurfacedPick {
            NavigationLink {
              DiaryEntryDetailView(store: environment.diaryStore, entryID: pick.entry.id)
            } label: {
              ResurfacedMemoryWhisper(pick: pick)
            }
            .buttonStyle(.plain)
          }

          if environment.toDoStore.activeItemCount > 0 {
            Button {
              selectedTab = .ourList
            } label: {
              IdeasWaitingRow(count: environment.toDoStore.activeItemCount)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }
    .scrollIndicators(.hidden)
  }
}
