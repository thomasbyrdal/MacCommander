//
//  ContentView.swift
//  MacCommander
//

import SwiftUI

struct ContentView: View {
    @State private var app = AppViewModel()

    var body: some View {
        MainWindowView(app: app)
            .frame(minWidth: 1000, minHeight: 640)
    }
}

#Preview {
    ContentView()
}
