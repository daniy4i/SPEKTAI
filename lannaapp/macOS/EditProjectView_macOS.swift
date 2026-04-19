//
//  EditProjectView_macOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct EditProjectView_macOS: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var type: Project.ProjectType
    @State private var status: Project.ProjectStatus
    
    init(project: Project) {
        self.project = project
        self._title = State(initialValue: project.title)
        self._description = State(initialValue: project.description)
        self._type = State(initialValue: project.type)
        self._status = State(initialValue: project.status)
    }
    
    var body: some View {
        VStack(spacing: DS.spacingL) {
            // Header
            HStack {
                Text("Edit Project")
                    .font(Typography.titleLarge)
                    .foregroundColor(DS.textPrimary)
                
                Spacer()
                
                HStack(spacing: DS.spacingS) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Save") {
                        saveProject()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty || description.isEmpty)
                }
            }
            .padding(.horizontal, DS.spacingL)
            .padding(.top, DS.spacingL)
            
            // Form
            Form {
                Section("Project Details") {
                    TextField("Title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                }
                
                Section("Project Type") {
                    Picker("Type", selection: $type) {
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
                
                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(Project.ProjectStatus.allCases, id: \.self) { status in
                            HStack {
                                Circle()
                                    .fill(Color(status.color))
                                    .frame(width: 12, height: 12)
                                Text(status.displayName)
                            }
                            .tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Project Info") {
                    HStack {
                        Text("Created")
                        Spacer()
                        Text(project.createdAt, format: .dateTime.day().month().year())
                            .foregroundColor(DS.textSecondary)
                    }
                    
                    HStack {
                        Text("Last Updated")
                        Spacer()
                        Text(project.updatedAt, format: .dateTime.day().month().year())
                            .foregroundColor(DS.textSecondary)
                    }
                }
            }
            .formStyle(GroupedFormStyle())
        }
        .frame(width: 600, height: 700)
        .background(DS.background)
    }
    
    private func saveProject() {
        // TODO: Implement project update through ProjectService
        print("Saving project: \(title)")
        dismiss()
    }
}

#Preview {
    EditProjectView_macOS(project: Project.mockProjects[0])
}
