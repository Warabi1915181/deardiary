import SwiftUI
import UIKit

struct AnniversaryCard: View {
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize
  var anniversaryDate: Date
  var numberOfDays: Int

  private var headingFont: Font {
    dynamicTypeSize.isAccessibilitySize ? .cardTitleCompact : .cardTitle
  }

  var body: some View {
    Card(verticalPadding: 16) {
      VStack(alignment: .leading, spacing: 8) {
        HStack(alignment: .top, spacing: 4) {
          Image(systemName: "heart.fill")
            .foregroundColor(Color("HeartRose"))
            .font(.system(size: 16))
            // Candlelight: the rose jewel glows faintly in the dark.
            .shadow(
              color: Color("HeartRose").opacity(colorScheme == .dark ? 0.55 : 0),
              radius: 5
            )
          Text("Our Anniversary")
            .font(headingFont)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
        }
        Text("\(numberOfDays)")
          .font(.displayNumber)
        Text("days left")
          .font(.bodyEmphasis)
        Text(anniversaryDate.formatted(date: .abbreviated, time: .omitted))
          .font(.metadata)
          .foregroundStyle(Color("InkMuted"))
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
          Text("Latest Memory")
            .font(headingFont)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .allowsTightening(true)
        }

        Text(entry.title)
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

struct HomeView: View {
  @Environment(AppEnvironment.self) private var environment

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

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        AnniversaryCard(anniversaryDate: anniversaryDate, numberOfDays: daysUntilAnniversary)
          // No memory yet: Anniversary becomes the focal surface and
          // catches the flame in Latest Memory's place.
          .candlelightCatchlight(environment.diaryStore.latestEntry == nil)
        if let latestEntry = environment.diaryStore.latestEntry {
          LatestMemoryCard(
            entry: latestEntry,
            photoURL: latestEntry.photos.first.map { environment.diaryStore.photoURL(for: $0) }
          )
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 16)
    }
    .scrollIndicators(.hidden)
  }
}
