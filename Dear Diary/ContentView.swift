//
//  ContentView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 21/03/2026.
//

import SwiftUI

struct ViewWithBackdrop<Content: View>: View {
  @ViewBuilder var content: Content

  var body: some View {
    ZStack {
      Color(.backdrop).ignoresSafeArea()
      content
    }
  }
}

struct ContentView: View {
  @StateObject private var diaryStore = DiaryStore()

  var body: some View {
    TabView {
      Tab("Home", systemImage: "house") {
        ViewWithBackdrop {
          HomeView(diaryStore: diaryStore)
        }
      }
      Tab("Diary", systemImage: "book.closed") {
        NavigationStack {
          ViewWithBackdrop {
            DiaryView(store: diaryStore)
          }
        }
      }
      Tab("Our List", systemImage: "list.bullet") {
        NavigationStack {
          ViewWithBackdrop {
            ToDoView()
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

  }
}

#Preview {
  ContentView()
}
