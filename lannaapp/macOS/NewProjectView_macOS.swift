//
//  NewProjectView_macOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct NewProjectView_macOS: View {
    @ObservedObject private var projectService = ProjectService()
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var selectedType = Project.ProjectType.story
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: DS.spacingL) {
            VStack(spacing: DS.spacingM) {
                Text("New Project")
                    .font(Typography.displayMedium)
                    .foregroundColor(DS.textPrimary)
                
                Text("Create a new creative project")
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.textSecondary)
            }
            
            VStack(spacing: DS.spacingM) {
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("Project Title")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    TextField("Enter project title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.bodyMedium)
                }
                
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("Description")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    TextField("Enter project description", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.bodyMedium)
                        .lineLimit(3...6)
                }
                
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("Project Type")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    Picker("Project Type", selection: $selectedType) {
                        ForEach(Project.ProjectType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.systemImage)
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
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
            }
            
            HStack(spacing: DS.spacingM) {
                Button("Cancel") {
                    dismiss()
                }
                .font(Typography.buttonText)
                .foregroundColor(DS.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.spacingM)
                .background(DS.textSecondary.opacity(0.1))
                .cornerRadius(DS.cornerRadius)
                
                Button(action: createProject) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(isLoading ? "Creating..." : "Create Project")
                            .font(Typography.buttonText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.spacingM)
                    .background(DS.primary)
                    .foregroundColor(.white)
                    .cornerRadius(DS.cornerRadius)
                }
                .disabled(isLoading || !isFormValid)
            }
            
            Spacer()
        }
        .frame(width: 500, height: 600)
        .padding(DS.spacingXL)
        .background(DS.background)
    }
    
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func createProject() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                try await projectService.createProject(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: selectedType
                )
                
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
}

#Preview {
    NewProjectView_macOS()
}
