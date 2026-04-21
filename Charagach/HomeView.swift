//
//  HomeView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

/// Root tab container shown once the user is authenticated.
struct HomeView: View {
    @ObservedObject var authViewModel: AuthViewModel

    private let plantSittingTabIcon = "person.2.fill"

    var body: some View {
        TabView {
            MarketplaceView(authViewModel: authViewModel)
                .tabItem {
                    Label("Marketplace", systemImage: "cart.fill")
                }

            PlantSittingView(authViewModel: authViewModel)
                .tabItem {
                    Label("Plant Sitting", systemImage: plantSittingTabIcon)
                }

            PlantCareView()
                .tabItem {
                    Label("Care Tips", systemImage: "leaf.fill")
                }

            ProfileView(authViewModel: authViewModel)
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
        .tint(.green)
    }
}
