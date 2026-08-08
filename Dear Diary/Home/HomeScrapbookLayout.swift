import SwiftUI
import UIKit

/// Home as a scrapbook page. Memory first, literally: the latest snapshot is
/// taped to the top of the page and owns the screen, and the two counts follow
/// underneath as a small paired note — near each other because they answer the
/// same question (how far we've come, what's next), small because neither is
/// the subject.
struct HomeScrapbookLayout: View {
  @Environment(AppEnvironment.self) private var environment
  let content: HomeContent
  @Binding var selectedTab: AppTab

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HomeGreetingLine()

      if let entry = content.latestEntry {
        NavigationLink {
          DiaryEntryDetailView(store: environment.diaryStore, entryID: entry.id)
        } label: {
          TapedMemory(entry: entry, photoURL: content.latestPhotoURL)
        }
        .buttonStyle(.plain)
        // The tape sits above the photo's top edge; give it room.
        .padding(.top, 12)
      }

      HStack(alignment: .top, spacing: 12) {
        // No memory yet: the days note is the page's focal surface and
        // catches the flame in the snapshot's place.
        DaysTogetherNote(content: content)
          .candlelightCatchlight(content.latestEntry == nil)

        if let milestone = content.milestone {
          NavigationLink {
            MilestonesView(store: environment.milestoneStore, diaryStore: environment.diaryStore)
          } label: {
            MilestoneNote(milestone: milestone)
          }
          .buttonStyle(.plain)
        }
      }
      .fixedSize(horizontal: false, vertical: true)

      HomeQuietTail(content: content, selectedTab: $selectedTab)
    }
  }
}

/// The page's opening line. Lives in the margin, never on a card — the room
/// speaking, not a surface.
struct HomeGreetingLine: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(handwritten: HomeGreetingText.greeting())
        .font(.regularItalic(size: 28))
      Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .font(.metadata)
        .foregroundStyle(Color("InkMuted"))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// The snapshot taped onto the page. There is no card here: the photo is the
/// object, and the writing sits on the page beneath it the way a caption sits
/// under a print.
private struct TapedMemory: View {
  let entry: DiaryEntry
  let photoURL: URL?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      if HomePhoto.exists(photoURL) {
        TapedPhoto {
          HomePhoto(url: photoURL, height: 240, cornerRadius: 4)
        }
        .padding(.horizontal, 4)
      }

      VStack(alignment: .leading, spacing: 4) {
        Text(handwritten: entry.title)
          .font(.regularItalic(size: 30))
          .foregroundStyle(Color("RomanceForeground"))
          .multilineTextAlignment(.leading)
        if !entry.body.isEmpty {
          Text(entry.body)
            .font(.body)
            .foregroundStyle(Color("RomanceForeground"))
            .lineLimit(2)
        }
        Text(entry.entryDate.formatted(date: .abbreviated, time: .omitted))
          .font(.metadata)
          .foregroundStyle(Color("InkMuted"))
          .padding(.top, 4)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 4)
    }
  }
}

/// Half of the paired note row. Small paper, one number, no heading — the
/// number and its words are one handwritten sentence.
private struct DaysTogetherNote: View {
  @Environment(\.colorScheme) private var colorScheme
  let content: HomeContent

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(content.daysTogether.formatted(.number.grouping(.automatic)))
        .font(.displayNumber)
        .foregroundStyle(Color("RomanceForeground"))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
      Text(handwritten: "days together")
        .font(.body)
      HStack(spacing: 4) {
        Image(systemName: "heart.fill")
          .font(.system(size: 10))
          .foregroundColor(Color("HeartRose"))
          // Candlelight: the rose jewel glows faintly in the dark.
          .shadow(
            color: Color("HeartRose").opacity(colorScheme == .dark ? 0.55 : 0),
            radius: 4
          )
        Text(content.anniversaryLine)
          .font(.metadata)
          .foregroundStyle(Color("InkMuted"))
          .lineLimit(2)
      }
    }
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    .padding(16)
    .paperSurface()
  }
}

private struct MilestoneNote: View {
  let milestone: HomeMilestone

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Image(systemName: milestone.icon)
        .font(.system(size: 18))
        .foregroundStyle(
          milestone.isHeart ? Color("HeartRose") : Color("RomanceForeground")
        )
        .padding(.bottom, 4)
      Text(handwritten: milestone.title)
        .font(.regularItalic(size: 22))
        .foregroundStyle(Color("RomanceForeground"))
        .lineLimit(2)
        .multilineTextAlignment(.leading)
      Text(milestone.relativeLine)
        .font(.metadata)
        .foregroundStyle(Color("InkMuted"))
    }
    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
    .padding(16)
    .paperSurface()
  }
}

/// The quiet tail the page ends on: a resurfaced memory and the ideas line,
/// each appearing only when it has something true to say.
struct HomeQuietTail: View {
  @Environment(AppEnvironment.self) private var environment
  let content: HomeContent
  @Binding var selectedTab: AppTab

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let pick = content.resurfaced {
        NavigationLink {
          DiaryEntryDetailView(store: environment.diaryStore, entryID: pick.entry.id)
        } label: {
          ResurfacedMemoryWhisper(pick: pick)
        }
        .buttonStyle(.plain)
      }

      if content.ideasWaiting > 0 {
        Button {
          selectedTab = .ourList
        } label: {
          IdeasWaitingRow(count: content.ideasWaiting)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 8)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// A photo read off disk, sized to a fixed height and clipped. Renders nothing
/// when the file is missing, so callers check `exists` before reserving space
/// for a frame — an empty piece of tape reads as a bug.
private struct HomePhoto: View {
  let url: URL?
  var height: CGFloat
  var cornerRadius: CGFloat = 0

  static func exists(_ url: URL?) -> Bool {
    guard let url else { return false }
    return FileManager.default.fileExists(atPath: url.path)
  }

  var body: some View {
    if let url, let image = UIImage(contentsOfFile: url.path) {
      Image(uiImage: image)
        .resizable()
        .scaledToFill()
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
  }
}

/// The paper treatment `Card` gives, applied to a view that owns its own
/// padding — the notes size themselves to a shared minimum height, so the
/// padding has to sit inside the frame rather than around it.
private struct PaperSurface: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  func body(content: Content) -> some View {
    content
      // Morning: paper on a desk — warm-tinted shadow, never neutral black.
      .background(Color("Surface"))
      .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
      .shadow(color: Color("WarmShadow").opacity(0.1), radius: 6, x: 0, y: 3)
      .overlay(
        // Candlelight: shadows retire, and the paper's top edge catches the
        // flame instead — a faint ember rim. Invisible by Morning.
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                Color("RomanceForeground").opacity(0.22),
                Color("RomanceForeground").opacity(0.03),
              ],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1
          )
          .opacity(colorScheme == .dark ? 1 : 0)
      )
  }
}

private extension View {
  func paperSurface() -> some View { modifier(PaperSurface()) }
}
