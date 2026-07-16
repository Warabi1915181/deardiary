//
//  ContentView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 21/03/2026.
//

import SwiftUI

struct ViewWithBackdrop<Content: View>: View {
  var atmosphere: BackdropAtmosphere
  @ViewBuilder var content: Content

  init(
    atmosphere: BackdropAtmosphere = .none,
    @ViewBuilder content: () -> Content
  ) {
    self.atmosphere = atmosphere
    self.content = content()
  }

  var body: some View {
    ZStack {
      Color(.backdrop).ignoresSafeArea()
      if atmosphere == .candlelightHome {
        CandlelightAtmosphere()
          .ignoresSafeArea()
      }
      content
    }
    // Handwritten body is the app default; SF only appears where a view
    // explicitly opts into .system.
    .font(.body)
  }
}

struct ContentView: View {
  @Environment(AppEnvironment.self) private var environment

  var body: some View {
    TabView {
      Tab("Home", systemImage: "house") {
        ViewWithBackdrop(atmosphere: .candlelightHome) {
          HomeView()
        }
      }
      Tab("Diary", systemImage: "book.closed") {
        NavigationStack {
          ViewWithBackdrop {
            DiaryView(store: environment.diaryStore)
          }
          // TEMP: stand-in entry point for Milestones until commit 4 adds the
          // Home "Next Milestone" card, which will replace this button.
          .toolbar {
            ToolbarItem(placement: .topBarLeading) {
              NavigationLink {
                MilestonesView(store: environment.milestoneStore)
              } label: {
                Image(systemName: "sparkles")
                  .foregroundStyle(Color("RomanceForeground"))
              }
            }
          }
        }
      }
      Tab("Our List", systemImage: "list.bullet") {
        NavigationStack {
          ViewWithBackdrop {
            ToDoView(store: environment.toDoStore)
          }
        }
      }
      Tab("Settings", systemImage: "gear") {
        NavigationStack {
          ViewWithBackdrop {
            SettingsMenuView()
          }
        }
      }
    }
    .tint(Color("RomanceForeground"))
    .overlay(alignment: .top) {
      syncBanner
    }
  }

  @ViewBuilder
  private var syncBanner: some View {
    switch environment.syncCoordinator.partnerSyncStatus {
    case .syncing:
      syncBannerLabel("Syncing...")
    case .offlineChangesSaved:
      syncBannerLabel("Offline changes saved")
    case .syncFailed:
      syncBannerLabel("Couldn't sync. Will retry.")
    default:
      EmptyView()
    }
  }

  private func syncBannerLabel(_ text: String) -> some View {
    Text(text)
      .font(.metadata)
      .foregroundStyle(Color("RomanceForeground"))
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(
        Capsule()
          .fill(Color("RomanceBackground"))
      )
      .padding(.top, 8)
  }
}

#Preview {
  ContentView()
    .environment(AppEnvironment())
}
