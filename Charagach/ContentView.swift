//
//  ContentView.swift
//  Charagach
//
//  Created by macOS on 1/24/26.
//

import SwiftUI

/// Root view that switches between the splash, authenticated, and unauthenticated flows.
struct ContentView: View {
    /// Single source of truth for auth state; the listener starts in AuthViewModel.init().
    @StateObject private var authViewModel = AuthViewModel()

    var body: some View {
        Group {
            if !authViewModel.isInitialized {
                // ── Splash ───
                // Shown briefly while the .initialSession event fires.
                VStack(spacing: 16) {
                    CharagachBrandLogo(size: 104)
                    ProgressView()
                        .tint(.green)
                }
            } else if authViewModel.isAuthenticated {
                HomeView(authViewModel: authViewModel)
            } else {
                LoginView(authViewModel: authViewModel)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
