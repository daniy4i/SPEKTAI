//
//  LoginView_iOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import AuthenticationServices


struct LoginView_iOS: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showingSignUp = false
    @State private var showingForgotPassword = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: DS.spacingXL) {
                // Header
                VStack(spacing: DS.spacingM) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(DS.primary)
                    
                    Text("Welcome Back")
                        .font(Typography.displayMedium)
                        .foregroundColor(DS.textPrimary)
                    
                    Text("Sign in to continue to your projects")
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
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    
                    VStack(alignment: .leading, spacing: DS.spacingS) {
                        Text("Password")
                            .font(Typography.label)
                            .foregroundColor(DS.textPrimary)
                        
                        SecureField("Enter your password", text: $password)
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
                    
                    Button(action: signIn) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Signing In..." : "Sign In")
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
                    SignInWithAppleButton(.signIn) { request in
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
                        Text("Don't have an account?")
                            .font(Typography.bodySmall)
                            .foregroundColor(DS.textSecondary)
                        
                        Button("Sign Up") {
                            showingSignUp = true
                        }
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.primary)
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Button("Forgot Password?") {
                        showingForgotPassword = true
                    }
                    .font(Typography.bodySmall)
                    .foregroundColor(DS.textSecondary)
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, DS.spacingXL)
                
                Spacer()
            }
            .background(DS.background)
            .navigationTitle("Sign In")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .sheet(isPresented: $showingSignUp) {
                SignUpView()
            }
            .sheet(isPresented: $showingForgotPassword) {
                ForgotPasswordView()
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await authService.signIn(email: email, password: password)
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
        print("🍎 [LoginView] Apple Sign-In result received")
        switch result {
        case .success(let authorization):
            print("🍎 [LoginView] Apple Sign-In authorization successful")
            Task {
                do {
                    print("🍎 [LoginView] Calling authService.signInWithApple(authorization:)...")
                    try await authService.signInWithApple(authorization: authorization)
                    print("🍎 [LoginView] Apple Sign-In completed successfully!")
                } catch {
                    print("❌ [LoginView] Apple Sign-In failed: \(error)")
                    print("❌ [LoginView] Error details: \(error.localizedDescription)")
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        case .failure(let error):
            print("❌ [LoginView] Apple Sign-In authorization failed: \(error)")
            print("❌ [LoginView] Error details: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
    

}

#Preview {
    LoginView_iOS()
}
