//
//  SignUpView_macOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import AuthenticationServices


struct SignUpView_macOS: View {
    @ObservedObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: DS.spacingXL) {
            // Header
            VStack(spacing: DS.spacingM) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 80))
                    .foregroundColor(DS.primary)
                
                Text("Create Account")
                    .font(Typography.displayMedium)
                    .foregroundColor(DS.textPrimary)
                
                Text("Sign up to start creating your projects")
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Form
            VStack(spacing: DS.spacingL) {
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("Email")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.bodyMedium)
                }
                
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("Password")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.bodyMedium)
                }
                
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("Confirm Password")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    SecureField("Confirm your password", text: $confirmPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.bodyMedium)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.error)
                        .padding(.horizontal, DS.spacingM)
                        .padding(.vertical, DS.spacingS)
                        .background(DS.error.opacity(0.1))
                        .cornerRadius(DS.cornerRadius)
                }
                
                Button(action: signUp) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Creating Account..." : "Create Account")
                            .font(Typography.buttonText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingM)
                    .background(DS.primary)
                    .foregroundColor(.white)
                    .cornerRadius(DS.cornerRadius)
                }
                .disabled(isLoading || !isFormValid)
                
                // Divider
                HStack {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DS.textSecondary.opacity(0.3))
                    
                    Text("or")
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.textSecondary)
                        .padding(.horizontal, DS.spacingM)
                    
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(DS.textSecondary.opacity(0.3))
                }
                .padding(.vertical, DS.spacingM)
                
                // Sign in with Apple button
                SignInWithAppleButton(.signUp) { request in
                    // Generate nonce and set it in the request
                    let nonce = authService.generateNonce()
                    request.nonce = authService.sha256Nonce(nonce)
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(DS.cornerRadius)
                

                
                HStack {
                    Text("Already have an account?")
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.textSecondary)
                    
                    Button("Sign In") {
                        dismiss()
                    }
                    .font(Typography.bodySmall)
                    .foregroundColor(DS.primary)
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, DS.spacingXL)
            
            Spacer()
        }
        .frame(width: 400, height: 600)
        .background(DS.background)
    }
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        password == confirmPassword &&
        password.count >= 6
    }
    
    private func signUp() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.signUp(email: email, password: password)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        print("🍎 [SignUpView] Apple Sign-In result received")
        switch result {
        case .success(let authorization):
            print("🍎 [SignUpView] Apple Sign-In authorization successful")
            Task {
                do {
                    print("🍎 [SignUpView] Calling authService.signInWithApple(authorization:)...")
                    try await authService.signInWithApple(authorization: authorization)
                    print("🍎 [SignUpView] Apple Sign-In completed successfully!")
                    await MainActor.run {
                        dismiss()
                    }
                } catch {
                    print("❌ [SignUpView] Apple Sign-In failed: \(error)")
                    print("❌ [SignUpView] Error details: \(error.localizedDescription)")
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            print("❌ [SignUpView] Apple Sign-In authorization failed: \(error)")
            print("❌ [SignUpView] Error details: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    

}

#Preview {
    SignUpView_macOS()
}
