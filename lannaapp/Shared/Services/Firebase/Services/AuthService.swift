//
//  AuthService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import CryptoKit
import FirebaseFirestore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


class AuthService: NSObject, ObservableObject {
    @Published var user: User?
    @Published var isAuthenticated = false
    @Published var isDeletingAccount = false

    static let shared = AuthService()

    // For Sign in with Apple
    private var currentNonce: String?

    // Demo/mock auth fallback key (used when Firebase project is not configured)
    private static let mockAuthEmailKey = "mockAuth_email"

    private override init() {
        super.init()

        // Restore mock auth session if present (Firebase not configured scenario)
        if UserDefaults.standard.string(forKey: Self.mockAuthEmailKey) != nil {
            isAuthenticated = true
            return
        }

        user = Auth.auth().currentUser
        isAuthenticated = user != nil

        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.user = user
                // Only update isAuthenticated from Firebase listener if not in mock mode
                if UserDefaults.standard.string(forKey: Self.mockAuthEmailKey) == nil {
                    self?.isAuthenticated = user != nil
                }
            }
        }
    }

    /// Activates local mock authentication (used when Firebase is not configured).
    @MainActor
    private func activateMockAuth(email: String) {
        UserDefaults.standard.set(email, forKey: Self.mockAuthEmailKey)
        self.isAuthenticated = true
    }

    /// Returns true if the error indicates Firebase is not properly configured.
    private func isFirebaseConfigError(_ error: NSError) -> Bool {
        // 17999 = FIRAuthErrorCodeInternalError (project not found / invalid config)
        // 17028 = FIRAuthErrorCodeAppNotAuthorized
        // 17020 = FIRAuthErrorCodeNetworkError (can't reach unconfigured project)
        return error.domain == "FIRAuthErrorDomain" &&
            [17999, 17028, 17020].contains(error.code)
    }

    // MARK: - Account Deletion

    /// Reauthenticate the current user using email/password.
    func reauthenticate(email: String, password: String) async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -10, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        _ = try await currentUser.reauthenticate(with: credential)
    }

    /// Deletes all Firestore data for the current user.
    private func deleteUserData(uid: String) async throws {
        let db = Firestore.firestore()

        // Helper to delete all documents in a collection reference
        func deleteAll(in collection: CollectionReference) async throws {
            let snapshot = try await collection.getDocuments()
            for doc in snapshot.documents {
                try await doc.reference.delete()
            }
        }

        // Delete user conversations and nested messages
        let userConversations = db.collection("users").document(uid).collection("conversations")
        let conversationsSnapshot = try await userConversations.getDocuments()
        for conv in conversationsSnapshot.documents {
            // Delete messages under user-level conversations
            try await deleteAll(in: conv.reference.collection("messages"))

            // Best-effort: delete any media under top-level conversations/{id}/media
            let topLevelConversationMedia = db.collection("conversations").document(conv.documentID).collection("media")
            do { try await deleteAll(in: topLevelConversationMedia) } catch { /* ignore if collection doesn't exist */ }

            // Delete the conversation document itself
            try await conv.reference.delete()
        }

        // Delete user projects and any nested conversations/messages
        let projectsSnapshot = try await db.collection("projects")
            .whereField("ownerUid", isEqualTo: uid)
            .getDocuments()
        for project in projectsSnapshot.documents {
            // If project has nested conversations, delete their messages too
            let nestedConversations = project.reference.collection("conversations")
            let nestedConversationsSnapshot = try await nestedConversations.getDocuments()
            for nested in nestedConversationsSnapshot.documents {
                try await deleteAll(in: nested.reference.collection("messages"))
                try await nested.reference.delete()
            }
            try await project.reference.delete()
        }

        // Finally, delete the user document if present
        let userDoc = db.collection("users").document(uid)
        do { try await userDoc.delete() } catch { /* ignore if not present */ }
    }

    /// Deletes the user's account and associated data.
    func deleteAccount() async throws {
        guard let currentUser = Auth.auth().currentUser else {
            throw NSError(domain: "AuthService", code: -11, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"])
        }

        await MainActor.run { self.isDeletingAccount = true }
        defer { Task { @MainActor in self.isDeletingAccount = false } }

        // Delete Firestore data first
        try await deleteUserData(uid: currentUser.uid)

        // Delete Firebase Authentication user
        do {
            try await currentUser.delete()
        } catch {
            // If recent login is required, surface error to UI to reauthenticate
            throw error
        }

        // Clear local auth state
        await MainActor.run {
            self.user = nil
            self.isAuthenticated = false
        }
    }
    
    func signIn(email: String, password: String) async throws {
        print("Attempting to sign in with email: \(email)")
        print("Firebase app configured: \(FirebaseApp.app() != nil)")

        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            print("Sign in successful for user: \(result.user.uid)")
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
            }
        } catch let error as NSError {
            print("Sign in failed with error: \(error), code: \(error.code), domain: \(error.domain)")
            if isFirebaseConfigError(error) {
                print("Firebase not configured — activating demo mode auth")
                await activateMockAuth(email: email)
            } else {
                throw error
            }
        }
    }

    func signUp(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            await MainActor.run {
                self.user = result.user
                self.isAuthenticated = true
            }
        } catch let error as NSError {
            print("Sign up failed with error: \(error), code: \(error.code), domain: \(error.domain)")
            if isFirebaseConfigError(error) {
                print("Firebase not configured — activating demo mode auth")
                await activateMockAuth(email: email)
            } else {
                throw error
            }
        }
    }
    
    func resetPassword(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
    
    func signOut() throws {
        // Clear mock auth session if present
        UserDefaults.standard.removeObject(forKey: Self.mockAuthEmailKey)
        try? Auth.auth().signOut()
        user = nil
        isAuthenticated = false
    }
    
    // MARK: - Sign in with Apple
    
    func signInWithApple(authorization: ASAuthorization) async throws {
        print("🍎 [Apple Sign-In] Processing Apple Sign-In authorization...")
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ [Apple Sign-In] ERROR: No Apple ID credential in authorization")
            throw NSError(domain: "AuthService", code: -4, userInfo: [NSLocalizedDescriptionKey: "No Apple ID credential found"])
        }
        
        print("🍎 [Apple Sign-In] Got Apple ID credential")
        print("🍎 [Apple Sign-In] User ID: \(appleIDCredential.user)")
        print("🍎 [Apple Sign-In] Email: \(appleIDCredential.email ?? "nil")")
        print("🍎 [Apple Sign-In] Full Name: \(appleIDCredential.fullName?.description ?? "nil")")
        print("🍎 [Apple Sign-In] Real User Status: \(appleIDCredential.realUserStatus.rawValue)")
        
        guard let nonce = currentNonce else {
            print("❌ [Apple Sign-In] ERROR: No nonce found!")
            throw NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid state: A login callback was received, but no login request was sent."])
        }
        print("🍎 [Apple Sign-In] Nonce found: \(nonce)")
        
        guard let appleIDToken = appleIDCredential.identityToken else {
            print("❌ [Apple Sign-In] ERROR: No identity token!")
            throw NSError(domain: "AuthService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch identity token"])
        }
        print("🍎 [Apple Sign-In] Identity token found: \(appleIDToken.count) bytes")
        
        guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            print("❌ [Apple Sign-In] ERROR: Cannot convert token to string!")
            throw NSError(domain: "AuthService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to serialize token string from data"])
        }
        print("🍎 [Apple Sign-In] Token string created: \(idTokenString.prefix(50))...")
        
        // Initialize a Firebase credential
        print("🍎 [Apple Sign-In] Creating Firebase credential...")
        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )
        print("🍎 [Apple Sign-In] Firebase credential created successfully")
        
        // Sign in with Firebase
        print("🍎 [Apple Sign-In] Signing in with Firebase...")
        let result = try await Auth.auth().signIn(with: credential)
        print("🍎 [Apple Sign-In] Firebase sign-in successful!")
        print("🍎 [Apple Sign-In] User UID: \(result.user.uid)")
        print("🍎 [Apple Sign-In] User Email: \(result.user.email ?? "nil")")
        
        await MainActor.run {
            self.user = result.user
            self.isAuthenticated = true
        }
        print("🍎 [Apple Sign-In] AuthService state updated")
    }
    
    func generateNonce() -> String {
        let nonce = randomNonceString()
        currentNonce = nonce
        print("🍎 [Apple Sign-In] Generated nonce: \(nonce)")
        return nonce
    }
    
    func sha256Nonce(_ nonce: String) -> String {
        return sha256(nonce)
    }
    

    
    // MARK: - Helper Methods
    
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length
        
        while remainingLength > 0 {
            let randoms: [UInt8] = (0 ..< 16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }
            
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }
        
        return result
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        
        return hashString
    }
    
    #if os(iOS)
    @MainActor
    private func getRootViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return nil
        }
        return window.rootViewController
    }
    #elseif os(macOS)
    @MainActor
    private func getRootViewController() -> NSViewController? {
        return NSApplication.shared.windows.first?.contentViewController
    }
    #endif
}
