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
  var body: some View {
    TabView {
      Tab("Home", systemImage: "house") {
        ViewWithBackdrop {
          HomeView()
        }
      }
      Tab("ToDo", systemImage: "list.bullet") {
        ViewWithBackdrop {
          ToDoView()
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
