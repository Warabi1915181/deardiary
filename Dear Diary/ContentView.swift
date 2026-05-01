//
//  ContentView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 21/03/2026.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    TabView {
      Tab("Home", systemImage: "house") {
        HomeView()
      }
    }

  }
}

#Preview {
  ContentView()
}
