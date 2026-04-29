//
//  ContentView.swift
//  Dear Diary
//
//  Created by Ho Ting Cheung on 21/03/2026.
//

import SwiftUI

struct ContentView: View {
  @State private var numberOfDays = 0

  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("一起了\(numberOfDays)天")
    }
  }
}

#Preview {
  ContentView()
}
