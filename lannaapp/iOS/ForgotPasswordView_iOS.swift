//
//  ForgotPasswordView_iOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import FirebaseAuth

struct ForgotPasswordView_iOS: View {
    @ObservedObject private var authService = AuthService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    
    var body: some View {
            VStack(spacing: DS.spacingL) {
                VStack(spacing: DS.spacingM) {
                    Text("Reset Password")
                        .font(Typography.displayMedium)
                        .foregroundColor(DS.textPrimary)
                    
                    Text("Enter your email address and we'll send you a link to reset your password")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: DS.spacingM) {
                    VStack(alignment: .leading, spacing: DS.spacingS) {
                        Text("Email")
                            .font(Typography.label)
                            .foregroundColor(DS.textPrimary)
                        
                        TextField("Enter your email", text: $email)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            #if os(iOS)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(Typography.bodySmall)
                            .foregroundColor(DS.error)
                    }
                    
                    if !successMessage.isEmpty {
                        Text(successMessage)
                            .font(Typography.bodySmall)
                            .foregroundColor(DS.success)
                    }
                }
                
                Button(action: resetPassword) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Sending..." : "Send Reset Link")
                            .font(Typography.buttonText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingM)
                    .background(DS.primary)
                    .foregroundColor(.white)
                    .cornerRadius(DS.cornerRadius)
                }
                .disabled(isLoading || email.isEmpty)
                
                Spacer()
            }
            .padding(DS.spacingXL)
            .background(DS.background)
            .navigationTitle("Reset Password")
    }
    
    private func resetPassword() {
        isLoading = true
        errorMessage = ""
        successMessage = ""
        
        Task {
            do {
                try await authService.resetPassword(email: email)
                await MainActor.run {
                    successMessage = "Reset link sent to your email"
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
}

#Preview {
    ForgotPasswordView_iOS()
}