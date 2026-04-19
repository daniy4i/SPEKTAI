//
//  AccountSettingsView_macOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import FirebaseAuth

struct AccountSettingsView_macOS: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var authService = AuthService.shared
    @State private var showingSubscription = false
    @State private var showingPermissions = false
    @State private var showingDeleteConfirm = false
    @State private var showingReauthSheet = false
    @State private var reauthPassword: String = ""
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    
    var body: some View {
        VStack(spacing: DS.spacingXL) {
            // Profile Header
            VStack(spacing: DS.spacingM) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(DS.primary)
                
                if let user = authService.user {
                    Text(user.email ?? "No Email")
                        .font(Typography.titleMedium)
                        .foregroundColor(DS.textPrimary)
                    
                    Text("User ID: \(user.uid)")
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.textSecondary)
                }
            }
            .padding(.top, DS.spacingXL)
            
            // Account Actions
            VStack(spacing: DS.spacingM) {
                // Subscription Section
                Button(action: { showingSubscription = true }) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 16))
                        Text("Subscription")
                            .font(Typography.bodyMedium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(DS.textSecondary)
                    }
                    .foregroundColor(DS.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingM)
                    .padding(.horizontal, DS.spacingM)
                    .background(DS.primary.opacity(0.1))
                    .cornerRadius(DS.spacingS)
                                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Permissions Section
                    Button(action: { showingPermissions = true }) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 16))
                            Text("Permissions")
                                .font(Typography.bodyMedium)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14))
                                .foregroundColor(DS.textSecondary)
                        }
                        .foregroundColor(DS.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.spacingM)
                        .padding(.horizontal, DS.spacingM)
                        .background(DS.primary.opacity(0.1))
                        .cornerRadius(DS.spacingS)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Delete Account (Apple Policy)
                    Button(role: .destructive, action: { showingDeleteConfirm = true }) {
                        HStack {
                            Image(systemName: "trash")
                                .font(.system(size: 16))
                            Text("Delete Account")
                                .font(Typography.bodyMedium)
                        }
                        .foregroundColor(DS.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.spacingM)
                        .background(DS.error.opacity(0.1))
                        .cornerRadius(DS.spacingS)
                    }
                    .buttonStyle(PlainButtonStyle())

                    Button(action: signOut) {
                    HStack {
                        Image(systemName: "power")
                            .font(.system(size: 16))
                        Text("Sign Out")
                            .font(Typography.bodyMedium)
                    }
                    .foregroundColor(DS.error)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingM)
                    .background(DS.error.opacity(0.1))
                    .cornerRadius(DS.spacingS)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(action: { dismiss() }) {
                    HStack {
                        Image(systemName: "xmark")
                            .font(.system(size: 16))
                        Text("Close")
                            .font(Typography.bodyMedium)
                    }
                    .foregroundColor(DS.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingM)
                    .background(DS.textSecondary.opacity(0.1))
                    .cornerRadius(DS.spacingS)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, DS.spacingXL)
            
            Spacer()
        }
        .frame(width: 400, height: 500)
        .background(DS.background)
        .navigationTitle("Account Settings")
                    .sheet(isPresented: $showingSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showingPermissions) {
                PermissionsView()
            }
            .alert("Delete Account?", isPresented: $showingDeleteConfirm) {
                Button("Delete", role: .destructive) { Task { await attemptDelete() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred.")
            }
            .sheet(isPresented: $showingReauthSheet) {
                ReauthSheetView_macOS(email: authService.user?.email ?? "", password: $reauthPassword) {
                    Task { await attemptReauthAndDelete() }
                }
            }
            .overlay {
                if authService.isDeletingAccount {
                    ZStack {
                        Color.black.opacity(0.25)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Deleting account…")
                                .font(Typography.bodySmall)
                                .foregroundColor(DS.textSecondary)
                        }
                        .padding()
                        .background(DS.background)
                        .cornerRadius(12)
                    }
                }
            }
    }
    
    private func signOut() {
        do {
            try authService.signOut()
            dismiss()
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

// MARK: - Reauth Sheet (Email/Password)

private struct ReauthSheetView_macOS: View {
    let email: String
    @Binding var password: String
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirm Your Identity").font(.headline)
            TextField("Email", text: .constant(email)).disabled(true)
            SecureField("Password", text: $password)
            Text("If you signed in with Apple, cancel and sign out, then sign in again with Apple and retry deletion.")
                .font(.footnote)
                .foregroundColor(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Reauthenticate & Delete", role: .destructive) { onConfirm() }
            }
        }
        .padding()
        .frame(width: 360)
    }
}

// MARK: - Delete Helpers

extension AccountSettingsView_macOS {
    private func attemptDelete() async {
        do {
            try await authService.deleteAccount()
            dismiss()
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain, nsError.code == AuthErrorCode.requiresRecentLogin.rawValue {
                await MainActor.run { self.showingReauthSheet = true }
            } else {
                await MainActor.run {
                    self.errorMessage = nsError.localizedDescription
                    self.showingErrorAlert = true
                }
            }
        }
    }

    private func attemptReauthAndDelete() async {
        guard let email = authService.user?.email, !reauthPassword.isEmpty else { return }
        do {
            try await authService.reauthenticate(email: email, password: reauthPassword)
            try await authService.deleteAccount()
            await MainActor.run { self.showingReauthSheet = false }
            dismiss()
        } catch {
            await MainActor.run {
                self.errorMessage = (error as NSError).localizedDescription
                self.showingErrorAlert = true
            }
        }
    }
}

#Preview {
    AccountSettingsView_macOS()
}
