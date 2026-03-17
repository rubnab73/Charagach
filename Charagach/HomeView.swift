//
//  HomeView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

/// Post-authentication screen shown when a user is signed in.
struct HomeView: View {
    /// Access to auth actions for signing out from the home screen.
    @ObservedObject var authViewModel: AuthViewModel
    var body: some View {
        // Example content for the authenticated area.
        Text("WELCOME HOME")
        // Allow the user to sign out and clear their session.
        Button("sign-out"){
            Task {
                await authViewModel.signOut()
            }
        }
    }
}
//
//#Preview {
//    HomeView()
//}
