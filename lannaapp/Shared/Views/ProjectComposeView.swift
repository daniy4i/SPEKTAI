import SwiftUI

struct ProjectComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var projectName: String = ""
    @FocusState private var isProjectNameFocused: Bool
    let onProjectCreated: (Project, String?) -> Void
    
    var body: some View {
        #if os(macOS)
        content
        #else
        NavigationStack {
            content
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DS.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        createProject()
                    }
                    .foregroundColor(DS.primary)
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #endif
    }
    
    private var content: some View {
        VStack(spacing: 0) {
                // Compose header with project name field
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Text("Project Name:")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(DS.textSecondary)
                        
                        TextField("Enter project name", text: $projectName)
                            .font(Typography.bodyMedium)
                            .textFieldStyle(.plain)
                            .autocorrectionDisabled()
                            .focused($isProjectNameFocused)
                            .onAppear {
                                // Focus and select all text when view appears
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    isProjectNameFocused = true
                                }
                            }
                    }
                    .padding(.horizontal, DS.spacingM)
                    .padding(.vertical, 12)
                    
                    Rectangle()
                        .fill(DS.textSecondary.opacity(0.2))
                        .frame(height: 0.5)
                }
                .background(DS.surface)
                
                // Chat area (initially empty with placeholder)
                ScrollView {
                    VStack(spacing: 20) {
                        Spacer(minLength: 100)
                        
                        // Lanna avatar
                        Circle()
                            .fill(DS.primary)
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text("A")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        VStack(spacing: 8) {
                            Text("New Project")
                                .font(Typography.titleLarge)
                                .fontWeight(.semibold)
                                .foregroundColor(DS.textPrimary)
                            
                            Text("Spekt is ready to help with your new project")
                                .font(Typography.bodyMedium)
                                .foregroundStyle(DS.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(DS.background)
            }
    }
    
    private func createProject() {
        let trimmedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedName.isEmpty else { return }
        
        let newProject = Project(
            title: trimmedName,
            description: "Project created with Spekt AI",
            createdAt: Date(),
            updatedAt: Date(),
            ownerUid: "",
            type: .general,
            status: .draft,
            coverImage: nil,
            activeConversationId: nil,
            conversationsCount: 0,
            isPinned: false
        )
        
        onProjectCreated(newProject, nil)
        #if os(iOS)
        dismiss()
        #endif
    }
}


#Preview {
    ProjectComposeView { project, firstMessage in
        print("Created project: \(project.title), first message: \(firstMessage ?? "none")")
    }
}
