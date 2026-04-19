//
//  ProjectSelectorView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

struct ProjectSelectorView: View {
    let onProjectSelected: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @StateObject private var projectService = ProjectService()
    @State private var searchText = ""
    
    var filteredProjects: [Project] {
        if searchText.isEmpty {
            return projectService.projects
        } else {
            return projectService.projects.filter { project in
                project.title.localizedCaseInsensitiveContains(searchText) ||
                project.description.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchView
                
                if projectService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    projectsList
                }
            }
            .background(DS.background)
            .navigationTitle("Select Project")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(Typography.label)
                    .foregroundColor(DS.primary)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("General Chat") {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            onProjectSelected(Project(
                                title: "General Chat",
                                description: "General conversation with Lanna AI",
                                createdAt: Date(),
                                updatedAt: Date(),
                                ownerUid: "",
                                type: .general,
                                status: .draft,
                                coverImage: nil,
                                activeConversationId: nil,
                                conversationsCount: 0,
                                isPinned: false
                            ))
                        }
                    }
                    .font(Typography.label)
                    .foregroundColor(DS.secondary)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 500)
        .onAppear {
            projectService.startListening()
        }
    }
    
    private var searchView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DS.textSecondary)
                .font(.system(size: 14))
            
            TextField("Search projects...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(Typography.bodyMedium)
        }
        .padding(.horizontal, DS.spacingS)
        .padding(.vertical, DS.spacingXS)
        .background(DS.textSecondary.opacity(0.1))
        .cornerRadius(DS.spacingXS)
        .padding(.horizontal, DS.spacingM)
        .padding(.vertical, DS.spacingS)
    }
    
    private var projectsList: some View {
        List {
            ForEach(filteredProjects) { project in
                HStack(spacing: DS.spacingS) {
                    Image(systemName: project.type.systemImage)
                        .font(.system(size: 16))
                        .foregroundColor(DS.primary)
                        .frame(width: 20, height: 20)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textPrimary)
                            .lineLimit(1)
                        
                        Text(project.description)
                            .font(Typography.bodySmall)
                            .foregroundColor(DS.textSecondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    if project.conversationsCount > 0 {
                        Text("\(project.conversationsCount)")
                            .font(Typography.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, DS.spacingXS)
                            .padding(.vertical, 1)
                            .background(DS.primary)
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, DS.spacingM)
                .padding(.vertical, DS.spacingS)
                .contentShape(Rectangle())
                .onTapGesture {
                    onProjectSelected(project)
                    dismiss()
                }
            }
        }
        .listStyle(PlainListStyle())
    }
}