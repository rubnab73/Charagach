//
//  LoginView.swift
//  Charagach
//
//  Created by macOS on 3/17/26.
//

import SwiftUI

// MARK: - LoginView

struct LoginView: View {
    @ObservedObject var authViewModel: AuthViewModel

    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var fullName = ""

    // UI state
    @State private var isSignUp = false
    @State private var showForgotPassword = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {

                // ── Header ──────────────────────────────────────────────
                VStack(spacing: 10) {
                    CharagachBrandLogo(size: 112)

                    Text("Charagach")
                        .font(.largeTitle.bold())

                    Text(isSignUp ? "Create your account" : "Welcome back")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 52)

                // ── Form Fields ──────────────────────────────────────────
                VStack(spacing: 14) {
                    if isSignUp {
                        TextField("Full Name", text: $fullName)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .autocorrectionDisabled()

                          SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(isSignUp ? .newPassword : .password)
                }

                // ── Error / Success Banners ─────────────────────────────
                if let error = authViewModel.errorMessage {
                    AuthBanner(message: error, isError: true)
                }
                if let success = authViewModel.successMessage {
                    AuthBanner(message: success, isError: false)
                }

                // ── Email Confirmation Pending ──────────────────────────
                if authViewModel.pendingEmailConfirmation {
                    VStack(spacing: 10) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.orange)
                        Text("Confirm your email")
                            .font(.headline)
                        Text("We sent a confirmation link to **\(email)**. Tap it to activate your account, then sign in.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                }

                // ── Primary Action Button ───────────────────────────────
                Button {
                    Task {
                        if isSignUp {
                            await authViewModel.signUp(
                                email: email,
                                password: password,
                                fullName: fullName
                            )
                        } else {
                            await authViewModel.signIn(email: email, password: password)
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if authViewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        }
                        Text(isSignUp ? "Create Account" : "Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(authViewModel.isLoading)

                // ── Forgot Password ─────────────────────────────────────
                if !isSignUp {
                    Button("Forgot Password?") {
                        authViewModel.errorMessage = nil
                        authViewModel.successMessage = nil
                        showForgotPassword = true
                    }
                    .font(.footnote)
                    .foregroundStyle(.green)
                }

                // ── Toggle Sign In / Sign Up ────────────────────────────
                Divider()

                HStack(spacing: 4) {
                    Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                        .foregroundStyle(.secondary)
                    Button(isSignUp ? "Sign In" : "Sign Up") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSignUp.toggle()
                            authViewModel.errorMessage = nil
                            authViewModel.successMessage = nil
                            authViewModel.pendingEmailConfirmation = false
                        }
                    }
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
                }
                .font(.footnote)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authViewModel: authViewModel)
        }
    }
}

struct CharagachBrandLogo: View {
    let size: CGFloat

    var body: some View {
        Image("CharagachLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityLabel("Charagach logo")
    }
}

// MARK: - Reusable Banner

private struct AuthBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .padding(.top, 1)
            Text(message)
                .font(.footnote)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .foregroundStyle(isError ? .red : .green)
        .padding(12)
        .background(
            (isError ? Color.red : Color.green).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 10)
        )
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "lock.rotation")
                    .font(.system(size: 68))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    Text("Forgot Password?")
                        .font(.title2.bold())
                    Text("Enter your email and we'll send you a link to reset your password.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                TextField("Email address", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocorrectionDisabled()

                if let error = authViewModel.errorMessage {
                    AuthBanner(message: error, isError: true)
                }
                if let success = authViewModel.successMessage {
                    AuthBanner(message: success, isError: false)
                }

                Button {
                    Task {
                        await authViewModel.sendPasswordReset(email: email)
                        // Auto-dismiss after showing success for 1.5 s
                        if authViewModel.successMessage != nil {
                            try? await Task.sleep(for: .seconds(1.5))
                            dismiss()
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white).scaleEffect(0.85)
                        }
                        Text("Send Reset Link")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(authViewModel.isLoading)

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 28)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.green)
                }
            }
        }
        .onAppear {
            authViewModel.errorMessage = nil
            authViewModel.successMessage = nil
        }
    }
}
