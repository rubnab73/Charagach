//
//  ContentView.swift
//  Charagach
//
//  Created by macOS on 1/24/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "tree.fill")
                .imageScale(.large)
                .foregroundColor(.green)
            Text("Hello, world!")
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
