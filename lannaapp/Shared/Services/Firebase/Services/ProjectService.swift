//
//  ProjectService.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class ProjectService: ObservableObject {
    @Published var projects: [Project] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    deinit {
        listener?.remove()
    }
    
    func startListening() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        isLoading = true
        
        listener = db.collection("projects")
            .whereField("ownerUid", isEqualTo: userId)
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching projects: \(error)")
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                Task { @MainActor in
                    self.projects = documents.compactMap { document in
                        try? document.data(as: Project.self)
                    }
                    self.isLoading = false
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    func createProject(title: String, description: String, type: Project.ProjectType) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("❌ ProjectService: User not authenticated")
            throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📝 ProjectService: Creating project for user \(userId)")
        
        let project = Project(
            title: title,
            description: description,
            createdAt: Date(),
            updatedAt: Date(),
            ownerUid: userId,
            type: type,
            status: .draft,
            coverImage: nil,
            activeConversationId: nil,
            conversationsCount: 0,
            isPinned: false
        )
        
        print("📝 ProjectService: Saving to Firestore...")
        let docRef = try await db.collection("projects")
            .addDocument(from: project)
        
        print("✅ ProjectService: Project created with ID: \(docRef.documentID)")
        return docRef.documentID
    }
    
    func updateProject(_ project: Project) async throws {
        guard let id = project.id else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }

        var updatedProject = project
        updatedProject.updatedAt = Date()
        updatedProject.ownerUid = userId

        try await db.collection("projects")
            .document(id)
            .setData(from: updatedProject)
    }
    
    func deleteProject(_ project: Project) async throws {
        guard let id = project.id else { return }
        guard Auth.auth().currentUser != nil else { return }
        
        try await db.collection("projects")
            .document(id)
            .delete()
    }
    
    func togglePinProject(_ project: Project) async throws {
        guard let id = project.id else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var updatedProject = project
        updatedProject.isPinned.toggle()
        updatedProject.updatedAt = Date()
        updatedProject.ownerUid = userId
        
        try await db.collection("projects")
            .document(id)
            .setData(from: updatedProject)
    }
    
    func archiveProject(_ project: Project) async throws {
        guard let id = project.id else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var updatedProject = project
        updatedProject.status = .archived
        updatedProject.updatedAt = Date()
        updatedProject.ownerUid = userId
        
        try await db.collection("projects")
            .document(id)
            .setData(from: updatedProject)
    }
    
    func unarchiveProject(_ project: Project) async throws {
        guard let id = project.id else { return }
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        var updatedProject = project
        updatedProject.status = .draft // Reset to draft when unarchiving
        updatedProject.updatedAt = Date()
        updatedProject.ownerUid = userId
        
        try await db.collection("projects")
            .document(id)
            .setData(from: updatedProject)
    }
}
