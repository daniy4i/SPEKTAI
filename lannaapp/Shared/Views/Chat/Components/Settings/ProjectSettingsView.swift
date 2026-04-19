//
//  ProjectSettingsView.swift
//  lannaapp
//
//  Extracted from ChatComponents.swift
//

import SwiftUI

struct ProjectSettingsView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @StateObject private var projectService = ProjectService()
    @StateObject private var mediaService = ProjectMediaService()
    @StateObject private var conversationService = ConversationService()

    @State private var title: String
    @State private var description: String
    @State private var selectedType: Project.ProjectType
    @State private var isPinned: Bool
    @State private var showingDeleteAlert = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingMediaGallery = false

    init(project: Project) {
        self.project = project
        self._title = State(initialValue: project.title)
        self._description = State(initialValue: project.description)
        self._selectedType = State(initialValue: project.type)
        self._isPinned = State(initialValue: project.isPinned)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Project Details") {
                    VStack(alignment: .leading, spacing: DS.spacingS) {
                        Text("Title")
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textSecondary)
                        TextField("Project Title", text: $title)
                            .font(Typography.bodyMedium)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: DS.spacingS) {
                        Text("Description")
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textSecondary)
                        TextField("Project Description", text: $description, axis: .vertical)
                            .font(Typography.bodyMedium)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...6)
                    }
                }



                Section("Options") {
                    Toggle("Pin Project", isOn: $isPinned)
                        .font(Typography.bodyMedium)
                }

                Section("Project Info") {
                    HStack {
                        Text("Created")
                            .foregroundColor(DS.textSecondary)
                        Spacer()
                        Text(project.createdAt, format: .dateTime.month().day().year())
                            .foregroundColor(DS.textPrimary)
                    }
                    .font(Typography.bodyMedium)

                    HStack {
                        Text("Last Updated")
                            .foregroundColor(DS.textSecondary)
                        Spacer()
                        Text(project.updatedAt, format: .dateTime.month().day().year())
                            .foregroundColor(DS.textPrimary)
                    }
                    .font(Typography.bodyMedium)

                    // Real conversation data
                    HStack {
                        Text("Conversations")
                            .foregroundColor(DS.textSecondary)
                        Spacer()
                        Text("\(conversationService.conversations.count)")
                            .foregroundColor(DS.textPrimary)
                    }
                    .font(Typography.bodyMedium)

                    if !conversationService.conversations.isEmpty {
                        HStack {
                            Text("Total Messages")
                                .foregroundColor(DS.textSecondary)
                            Spacer()
                            Text("\(totalMessagesCount)")
                                .foregroundColor(DS.textPrimary)
                        }
                        .font(Typography.bodyMedium)

                        HStack {
                            Text("Last Activity")
                                .foregroundColor(DS.textSecondary)
                            Spacer()
                            if let lastActivity = mostRecentActivityDate {
                                Text(lastActivity, format: .dateTime.month().day().hour().minute())
                                    .foregroundColor(DS.textPrimary)
                            } else {
                                Text("No activity")
                                    .foregroundColor(DS.textSecondary)
                            }
                        }
                        .font(Typography.bodyMedium)
                    }
                }

                Section("Media Files") {
                    let summary = mediaService.summary

                    if mediaService.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Loading media files...")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textSecondary)
                        }
                        .padding(.vertical, DS.spacingS)
                    } else if summary.totalCount > 0 {
                        VStack(alignment: .leading, spacing: DS.spacingS) {
                            // Media summary row
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .foregroundColor(DS.primary)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Project Media")
                                        .font(Typography.bodyMedium)
                                        .foregroundColor(DS.textPrimary)

                                    Text("\(summary.totalCount) files • \(summary.formattedTotalSize)")
                                        .font(Typography.caption)
                                        .foregroundColor(DS.textSecondary)
                                }

                                Spacer()

                                Button("View All") {
                                    showingMediaGallery = true
                                }
                                .font(Typography.caption)
                                .foregroundColor(DS.primary)
                            }

                            // Media type breakdown
                            HStack(spacing: DS.spacingM) {
                                if summary.audioCount > 0 {
                                    mediaTypeChip(
                                        icon: "mic.fill",
                                        count: summary.audioCount,
                                        label: "Audio"
                                    )
                                }

                                if summary.videoCount > 0 {
                                    mediaTypeChip(
                                        icon: "video.fill",
                                        count: summary.videoCount,
                                        label: "Video"
                                    )
                                }

                                if summary.imageCount > 0 {
                                    mediaTypeChip(
                                        icon: "photo.fill",
                                        count: summary.imageCount,
                                        label: "Images"
                                    )
                                }

                                Spacer()
                            }
                        }
                        .padding(.vertical, DS.spacingXS)
                    } else {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                                .foregroundColor(DS.textSecondary)
                                .frame(width: 20)
                            Text("No media files yet")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textSecondary)
                            Spacer()
                        }
                        .padding(.vertical, DS.spacingS)
                    }
                }

                Section {
                    Button("Delete Project") {
                        showingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                    .font(Typography.bodyMedium)
                }
            }
            .navigationTitle("Project Settings")
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
                    .disabled(isLoading || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Delete Project", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteProject()
                }
            } message: {
                Text("Are you sure you want to delete \"\(project.title)\"? This action cannot be undone.")
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
            .sheet(isPresented: $showingMediaGallery) {
                ProjectMediaGalleryView(project: project)
            }
        }
        .onAppear {
            Task {
                await loadProjectData()
            }
        }
        .onDisappear {
            conversationService.stopListening()
        }
    }

    // MARK: - Computed Properties

    private var totalMessagesCount: Int {
        conversationService.conversations.reduce(0) { total, conversation in
            total + conversation.messagesCount
        }
    }

    private var mostRecentActivityDate: Date? {
        conversationService.conversations
            .map(\.lastMessageAt)
            .max()
    }

    // MARK: - Helper Views

    private func mediaTypeChip(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: DS.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DS.primary)

            Text("\(count)")
                .font(Typography.caption)
                .foregroundColor(DS.textPrimary)
                .fontWeight(.medium)

            Text(label)
                .font(Typography.caption)
                .foregroundColor(DS.textSecondary)
        }
        .padding(.horizontal, DS.spacingS)
        .padding(.vertical, DS.spacingXS)
        .background(DS.primary.opacity(0.1))
        .cornerRadius(DS.spacingS)
    }

    // MARK: - Helper Functions

    private func loadProjectData() async {
        guard let projectId = project.id else { return }

        // Load media data asynchronously
        await mediaService.loadProjectMedia(projectId: projectId)

        // Start listening to conversations for this project
        conversationService.startListeningToConversations(projectId: projectId)
    }

    private func saveChanges() {
        isLoading = true
        errorMessage = nil

        var updatedProject = project
        updatedProject.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.type = selectedType
        updatedProject.isPinned = isPinned
        updatedProject.updatedAt = Date()

        Task {
            do {
                try await projectService.updateProject(updatedProject)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to update project: \(error.localizedDescription)"
                }
            }
        }
    }

    private func deleteProject() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await projectService.deleteProject(project)
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = "Failed to delete project: \(error.localizedDescription)"
                }
            }
        }
    }
}