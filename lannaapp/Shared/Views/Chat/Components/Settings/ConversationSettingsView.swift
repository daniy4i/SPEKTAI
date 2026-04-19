//
//  ConversationSettingsView.swift
//  lannaapp
//
//  Individual conversation settings and management
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ConversationSettingsView: View {
    let conversation: Conversation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var conversationService = ConversationService()

    @State private var conversationTitle: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var showingExportOptions = false
    @State private var showingClearAlert = false

    init(conversation: Conversation) {
        self.conversation = conversation
        self._conversationTitle = State(initialValue: conversation.projectName ?? "Untitled Conversation")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Conversation Details") {
                    VStack(alignment: .leading, spacing: DS.spacingS) {
                        Text("Title")
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textSecondary)
                        TextField("Conversation Title", text: $conversationTitle)
                            .font(Typography.bodyMedium)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Information") {
                    HStack {
                        Text("Created")
                            .foregroundColor(DS.textSecondary)
                        Spacer()
                        Text(conversation.createdAt, format: .dateTime.month().day().year().hour().minute())
                            .foregroundColor(DS.textPrimary)
                    }
                    .font(Typography.bodyMedium)

                    HStack {
                        Text("Last Message")
                            .foregroundColor(DS.textSecondary)
                        Spacer()
                        Text(conversation.lastMessageAt, format: .dateTime.month().day().hour().minute())
                            .foregroundColor(DS.textPrimary)
                    }
                    .font(Typography.bodyMedium)

                    HStack {
                        Text("Messages")
                            .foregroundColor(DS.textSecondary)
                        Spacer()
                        Text("\(conversation.messagesCount)")
                            .foregroundColor(DS.textPrimary)
                    }
                    .font(Typography.bodyMedium)

                    if !conversation.lastMessage.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spacingXS) {
                            Text("Last Message Preview")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textSecondary)
                            Text(conversation.lastMessage)
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textPrimary)
                                .lineLimit(3)
                                .padding(.vertical, DS.spacingXS)
                                .padding(.horizontal, DS.spacingS)
                                .background(DS.surface)
                                .cornerRadius(DS.spacingS)
                        }
                    }
                }

                Section("Shared Context") {
                    if let sharedContext = conversation.sharedContext, !sharedContext.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spacingXS) {
                            Text("Context")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textSecondary)
                            Text(sharedContext)
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textPrimary)
                                .lineLimit(5)
                                .padding(.vertical, DS.spacingXS)
                                .padding(.horizontal, DS.spacingS)
                                .background(DS.surface)
                                .cornerRadius(DS.spacingS)
                        }
                    } else {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(DS.textSecondary)
                            Text("No shared context")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textSecondary)
                        }
                    }

                    if let documents = conversation.sharedDocuments, !documents.isEmpty {
                        VStack(alignment: .leading, spacing: DS.spacingXS) {
                            Text("Shared Documents (\(documents.count))")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textSecondary)

                            ForEach(documents, id: \.name) { document in
                                HStack {
                                    Image(systemName: "doc.fill")
                                        .foregroundColor(DS.primary)
                                        .font(.system(size: 12))
                                    Text(document.name)
                                        .font(Typography.caption)
                                        .foregroundColor(DS.textPrimary)
                                    Spacer()
                                    Text(document.type.uppercased())
                                        .font(Typography.caption)
                                        .foregroundColor(DS.textSecondary)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }

                Section("Actions") {
                    Button("Export Conversation") {
                        showingExportOptions = true
                    }
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.primary)

                    Button("Clear Messages") {
                        showingClearAlert = true
                    }
                    .font(Typography.bodyMedium)
                    .foregroundColor(.orange)
                }

                Section {
                    Button("Delete Conversation") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                    .font(Typography.bodyMedium)
                }
            }
            .navigationTitle("Conversation Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isLoading || conversationTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Conversation", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteConversation()
                }
            } message: {
                Text("Are you sure you want to delete this conversation? This action cannot be undone and will permanently delete all messages and media files.")
            }
            .alert("Clear Messages", isPresented: $showingClearAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear", role: .destructive) {
                    clearMessages()
                }
            } message: {
                Text("Are you sure you want to clear all messages? This will permanently delete all messages but keep the conversation.")
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .actionSheet(isPresented: $showingExportOptions) {
                ActionSheet(
                    title: Text("Export Conversation"),
                    message: Text("Choose export format"),
                    buttons: [
                        .default(Text("Text File (.txt)")) {
                            exportAsText()
                        },
                        .default(Text("JSON File (.json)")) {
                            exportAsJSON()
                        },
                        .default(Text("Share Messages")) {
                            shareMessages()
                        },
                        .cancel()
                    ]
                )
            }
        }
    }

    // MARK: - Actions

    private func saveChanges() {
        guard !conversationTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let conversationId = conversation.id else {
            return
        }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Update only the projectName field in Firestore
                guard let userId = Auth.auth().currentUser?.uid else {
                    throw NSError(domain: "AuthError", code: 0, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
                }

                let db = Firestore.firestore()
                try await db.collection("users")
                    .document(userId)
                    .collection("conversations")
                    .document(conversationId)
                    .updateData([
                        "projectName": conversationTitle.trimmingCharacters(in: .whitespacesAndNewlines),
                        "updatedAt": Date()
                    ])

                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update conversation: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteConversation() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await conversationService.deleteConversation(conversation)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to delete conversation: \(error.localizedDescription)"
                }
            }
        }
    }

    private func clearMessages() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                // TODO: Implement clear messages functionality
                print("Clear messages for conversation: \(conversation.id ?? "unknown")")
                await MainActor.run {
                    isLoading = false
                    // Could show success message
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to clear messages: \(error.localizedDescription)"
                }
            }
        }
    }

    private func exportAsText() {
        // TODO: Implement text export
        print("Export as text")
    }

    private func exportAsJSON() {
        // TODO: Implement JSON export
        print("Export as JSON")
    }

    private func shareMessages() {
        // TODO: Implement share messages
        print("Share messages")
    }
}

// MARK: - Preview
#if DEBUG
struct ConversationSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationSettingsView(conversation: .init(
            id: "1",
            userId: "user1",
            projectId: "project1",
            projectName: "Test Conversation",
            lastMessage: "This is a test message",
            lastMessageAt: Date(),
            lastMessageTime: Date(),
            messagesCount: 5,
            updatedAt: Date(),
            createdAt: Date(),
            sharedContext: "This is some shared context for the conversation",
            sharedDocuments: nil
        ))
    }
}
#endif