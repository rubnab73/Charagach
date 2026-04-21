//
//  AuthViewModel.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI
import Supabase
import Combine

@MainActor
/// View model responsible for handling authentication state and actions using Supabase.
class AuthViewModel: ObservableObject {

    // MARK: - Published State

    /// The current authenticated session. Nil when signed out or pending email confirmation.
    @Published var session: Session?
    /// True once the user is fully authenticated (session present and email confirmed).
    @Published var isAuthenticated = false
    /// True while a network request is in flight – used to show loading indicators.
    @Published var isLoading = false
    /// Set on any auth failure; cleared before every new request.
    @Published var errorMessage: String?
    /// Set on a successful but non-navigating action (e.g. password-reset email sent).
    @Published var successMessage: String?
    /// True after sign-up when Supabase requires the user to confirm their email first.
    @Published var pendingEmailConfirmation = false
    /// False until the `.initialSession` event fires so the UI can show a proper splash.
    @Published var isInitialized = false

    // MARK: - Init

    init() {
        // Start listening immediately; the first event (.initialSession) fires quickly
        // and sets isInitialized, eliminating any flash to the login screen on relaunch.
        Task { await listenToAuthChanges() }
    }

    // MARK: - Auth State Listener

    /// Observes the Supabase auth event stream for the lifetime of this view model.
    private func listenToAuthChanges() async {
        for await (event, session) in await supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                // Fired once on startup with the persisted session (or nil if none).
                self.session = session
                self.isAuthenticated = session != nil
                self.isInitialized = true

            case .signedIn:
                self.session = session
                self.isAuthenticated = true
                self.pendingEmailConfirmation = false

            case .signedOut:
                self.session = nil
                self.isAuthenticated = false

            case .tokenRefreshed, .userUpdated:
                // Keep the local session in sync with the refreshed token.
                self.session = session

            case .passwordRecovery:
                // The user tapped a password-reset link. You can navigate to a
                // "choose new password" screen here in a future iteration.
                break

            default:
                break
            }
        }
    }

    // MARK: - Sign Up

    /// Creates a new account. Passes `fullName` as user metadata so it is stored
    /// in `auth.users.raw_user_meta_data` and can be copied into a profiles table
    /// via a Supabase database trigger.
    func signUp(email: String, password: String, fullName: String) async {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your full name."
            return
        }
        guard validateForm(email: email, password: password) else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let response = try await supabase.auth.signUp(
                email: email,
                password: password,
                data: ["full_name": AnyJSON.string(fullName)]
            )
            if response.session == nil {
                // Email confirmation is enabled in the Supabase dashboard.
                pendingEmailConfirmation = true
                successMessage = "A confirmation link has been sent to \(email). Please check your inbox before signing in."
            } else {
                self.session = response.session
                self.isAuthenticated = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign In

    func signIn(email: String, password: String) async {
        guard validateForm(email: email, password: password) else { return }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            let session = try await supabase.auth.signIn(email: email, password: password)
            self.session = session
            self.isAuthenticated = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() async {
        do {
            try await supabase.auth.signOut()
            self.session = nil
            self.isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Password Reset

    /// Sends a password-reset email. The user taps the link, which deep-links back
    /// into the app and fires a `.passwordRecovery` auth event.
    func sendPasswordReset(email: String) async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your email address."
            return
        }
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        do {
            try await supabase.auth.resetPasswordForEmail(email)
            successMessage = "Password reset email sent. Check your inbox."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Validation

    /// Validates that the email field is not empty before hitting the network.
    @discardableResult
    private func validateForm(email: String, password: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        guard !trimmedEmail.isEmpty else {
            errorMessage = "Email cannot be empty."
            return false
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty."
            return false
        }
        return true
    }
}
