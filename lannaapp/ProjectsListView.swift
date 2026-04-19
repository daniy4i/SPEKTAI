//
//  ProjectsListView.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import FirebaseAuth
import AVFoundation
#if os(iOS)
import UIKit
#endif

enum AppView {
    case projects
    case conversations(Project)
    case chat(Conversation)
}


struct ProjectsListView: View {
    @StateObject private var projectService = ProjectService()
    @StateObject private var conversationService = ConversationService()
    @ObservedObject private var authService = AuthService.shared
    @State private var selectedConversation: Conversation?
    @State private var selectedProject: Project?
    @State private var showingNewProject = false
    @State private var isComposingProject = false
    @State private var searchText = ""
    @State private var showingAccountSettings = false
    @State private var showingProjectSettings = false
    @State private var showingConversationSettings = false
    @State private var showingVoiceMemo = false
    @State private var showingRealtimeMode = false
    @State private var currentView: AppView = .projects
    @AppStorage("hasCompletedSmartGlassesSetup") private var hasCompletedSmartGlassesSetup = false
    @State private var showingSmartGlassesSetup = false
    @State private var showingMediaTransfer = false
    @State private var pendingCaptureRequest: CaptureRequest?
    @State private var captureMenuError: String?
    @State private var showingCaptureMenuError = false
    @StateObject private var smartGlassesService = SmartGlassesService.shared
    @State private var showingPhotoTakenAlert = false
    
    var filteredProjects: [Project] {
        let projects: [Project]
        if searchText.isEmpty {
            projects = projectService.projects
        } else {
            projects = projectService.projects.filter { project in
                project.title.localizedCaseInsensitiveContains(searchText) ||
                project.description.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort projects: pinned first, then by updatedAt
        return projects.sorted { project1, project2 in
            if project1.isPinned != project2.isPinned {
                return project1.isPinned // Pinned projects come first
            }
            return project1.updatedAt > project2.updatedAt // Most recent first
        }
    }
    
    var filteredConversations: [Conversation] {
        // First filter by project ID if we have a selected project
        let projectFilteredConversations: [Conversation]
        if let selectedProject = selectedProject, let projectId = selectedProject.id {
            projectFilteredConversations = conversationService.conversations.filter { conversation in
                conversation.projectId == projectId
            }
        } else {
            projectFilteredConversations = conversationService.conversations
        }
        
        // Then apply search filter if needed
        if searchText.isEmpty {
            return projectFilteredConversations
        } else {
            return projectFilteredConversations.filter { conversation in
                conversation.lastMessage.localizedCaseInsensitiveContains(searchText) ||
                (conversation.projectName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        Group {
            switch currentView {
            case .projects:
                projectsView
            case .conversations(let project):
                conversationsView(for: project)
            case .chat(let conversation):
                chatThreadView(for: conversation)
            }
        }
        .onAppear {
            projectService.startListening()
            // Note: Conversations will be loaded when a project is selected
        }
        .onDisappear {
            projectService.stopListening()
            conversationService.stopListening()
        }
        .sheet(isPresented: $showingNewProject) {
            ProjectComposeView { project, firstMessage in
                // Handle project creation and first message
                Task {
                    do {
                        let projectId = try await projectService.createProject(
                            title: project.title,
                            description: project.description,
                            type: project.type
                        )
                        
                        // Create first conversation with message if provided
                        if let message = firstMessage, !message.isEmpty {
                            try await conversationService.createConversation(
                                projectId: projectId,
                                projectName: project.title,
                                initialMessage: message
                            )
                        }
                    } catch {
                        print("Error creating project: \(error)")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAccountSettings) {
            AccountSettingsView()
        }
        .sheet(isPresented: $showingProjectSettings) {
            if let selectedProject = selectedProject {
                ProjectSettingsView(project: selectedProject)
            }
        }
        .sheet(isPresented: $showingSmartGlassesSetup) {
            NavigationView {
                SmartGlassesSetupView(isSetupComplete: $hasCompletedSmartGlassesSetup)
            }
        }
        .sheet(isPresented: $showingMediaTransfer) {
            SmartGlassesMediaTransferView()
        }
        .sheet(isPresented: $showingRealtimeMode) {
            RealtimeModeSheet()
        }
        .sheet(isPresented: $showingVoiceMemo) {
            #if os(iOS)
            VoiceMemoView_iOS(project: selectedProject)
            #else
            VoiceMemoView_macOS(project: selectedProject)
            #endif
        }
        .sheet(isPresented: $showingConversationSettings) {
            if let selectedConversation = selectedConversation {
                ConversationSettingsView(conversation: selectedConversation)
            }
        }
        .alert("Capture", isPresented: $showingCaptureMenuError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(captureMenuError ?? "Open a conversation before starting Listen or Watch Mode.")
        }
        .alert("Photo Taken!", isPresented: $showingPhotoTakenAlert) {
            Button("View Photos") {
                showingSmartGlassesSetup = true
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("A new photo was captured on your smart glasses. \(smartGlassesService.mediaSummary.photos) photos available.")
        }
        #if canImport(QCSDK) && os(iOS)
        .onChange(of: smartGlassesService.photoWasTaken) { wasTaken in
            if wasTaken {
                // Only open UI if app is in foreground
                let appState = UIApplication.shared.applicationState
                if appState == .active {
                    print("📱 Opening realtime view (foreground)")
                    showingRealtimeMode = true
                }
                smartGlassesService.photoWasTaken = false
            }
        }
        #endif
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRealtimeView"))) { _ in
            // Handle notification tap from background - open view
            print("📱 Opening realtime view from notification tap")
            showingRealtimeMode = true
        }
    }
    
    // MARK: - View Components
    
    // iMessage-style Header
    private var iMessageHeaderView: some View {
        VStack(spacing: 0) {
            // Main header
            HStack {
                Menu {
                    Button(action: {
                        showingSmartGlassesSetup = true
                    }) {
                        Label("Smart Glasses Setup", systemImage: "eyeglasses")
                    }

                    Button(action: {
                        showingMediaTransfer = true
                    }) {
                        Label("Download Media", systemImage: "square.and.arrow.down")
                    }
                } label: {
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }
                .help("Smart Glasses")

                Spacer()

                Text("Spekt")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)

                Spacer()

                HStack(spacing: 16) {
                    Button(action: {
                        showingNewProject = true
                    }) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        showingAccountSettings = true
                    }) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                    .font(.system(size: 16))
                
                TextField("Search", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 17))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .background(Color.black)
    }
    
    // iMessage-style Project Row
    private func iMessageProjectRow(project: Project) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                
                if let firstChar = project.title.first {
                    Text(String(firstChar))
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: project.type.systemImage)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(project.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(formatTimestamp(project.updatedAt))
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.gray)
                }
                
                HStack {
                    Text(project.description)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if project.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                }
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    // Helper function to format timestamps like iMessage
    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(date) == true {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
    
    private var projectsView: some View {
        Group {
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use split view
                HStack(spacing: 0) {
                    sidebarView
                    detailView
                }
            } else {
                // iPhone: Use full screen list
                fullScreenProjectsView
            }
            #else
            // macOS: Use split view
            HStack(spacing: 0) {
                sidebarView
                detailView
            }
            #endif
        }
    }
    
    private var fullScreenProjectsView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // iMessage-style Header with safe area padding
                iMessageHeaderView
                    .padding(.top)

                // Projects list with iMessage styling
                if projectService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredProjects) { project in
                                iMessageProjectRow(project: project)
                                    .onTapGesture {
                                        selectProject(project)
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                        // Pin/Unpin action
                                        Button(action: {
                                            togglePinProject(project)
                                        }) {
                                            VStack {
                                                Image(systemName: project.isPinned ? "pin.slash" : "pin")
                                                    .font(.system(size: 20))
                                                Text(project.isPinned ? "Unpin" : "Pin")
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundColor(.white)
                                        }
                                        .tint(project.isPinned ? .orange : .blue)
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        // Archive action
                                        if project.status != .archived {
                                            Button(action: {
                                                archiveProject(project)
                                            }) {
                                                VStack {
                                                    Image(systemName: "archivebox")
                                                        .font(.system(size: 20))
                                                    Text("Archive")
                                                        .font(.system(size: 12))
                                                }
                                                .foregroundColor(.white)
                                            }
                                            .tint(.orange)
                                        } else {
                                            Button(action: {
                                                unarchiveProject(project)
                                            }) {
                                                VStack {
                                                    Image(systemName: "tray.and.arrow.up")
                                                        .font(.system(size: 20))
                                                    Text("Unarchive")
                                                        .font(.system(size: 12))
                                                }
                                                .foregroundColor(.white)
                                            }
                                            .tint(.green)
                                        }
                                    }
                            }
                        }
                        .background(Color.black)
                    }
                }
            }
            .background(Color.black)
            #if os(iOS)
            .navigationBarHidden(true)
            .ignoresSafeArea(edges: .bottom)
            #endif
        }
        .navigationViewStyle(.stack)
    }
    
    private func conversationsView(for project: Project) -> some View {
        NavigationView {
            conversationsList
            .navigationTitle(project.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        currentView = .projects
                        selectedProject = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Spekt")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        currentView = .projects
                        selectedProject = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Spekt")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                }
                #endif
                
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedConversation != nil {
                        // Show conversation menu when in a conversation
                        Menu {
                            Button(action: {
                                showingConversationSettings = true
                            }) {
                                Label("Conversation Settings", systemImage: "gear")
                            }

                            Button(action: {
                                // Export conversation action
                            }) {
                                Label("Export Chat", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(action: {
                                // Clear conversation action
                            }) {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Conversation Options")
                    } else {
                        // Show project settings when viewing conversations list
                        Button(action: {
                            showingProjectSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Project Settings")
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    if selectedConversation != nil {
                        // Show conversation menu when in a conversation
                        Menu {
                            Button(action: {
                                showingConversationSettings = true
                            }) {
                                Label("Conversation Settings", systemImage: "gear")
                            }

                            Button(action: {
                                // Export conversation action
                            }) {
                                Label("Export Chat", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(action: {
                                // Clear conversation action
                            }) {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Conversation Options")
                    } else {
                        // Show project settings when viewing conversations list
                        Button(action: {
                            showingProjectSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Project Settings")
                    }
                }
                #endif
            }
        }
        .onAppear {
            if let projectId = project.id {
                conversationService.startListeningToConversations(projectId: projectId)
            } else {
                conversationService.startListeningToConversations()
            }
        }
    }
    
    private func chatThreadView(for conversation: Conversation) -> some View {
        NavigationView {
            Group {
                #if os(iOS)
                ChatMessagesView_iOS(
                    conversation: conversation,
                    conversationService: conversationService,
                    captureRequest: Binding(
                        get: { pendingCaptureRequest },
                        set: { pendingCaptureRequest = $0 }
                    )
                )
                #else
                ChatMessagesView(
                    conversation: conversation,
                    conversationService: conversationService,
                    captureRequest: Binding(
                        get: { pendingCaptureRequest },
                        set: { pendingCaptureRequest = $0 }
                    )
                )
                #endif
            }
            .navigationTitle(conversation.projectName ?? "Chat")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        if let project = selectedProject {
                            currentView = .conversations(project)
                        } else {
                            currentView = .projects
                        }
                        selectedConversation = nil
                        pendingCaptureRequest = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        if let project = selectedProject {
                            currentView = .conversations(project)
                        } else {
                            currentView = .projects
                        }
                        selectedConversation = nil
                        pendingCaptureRequest = nil
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .medium))
                            Text("Back")
                                .font(.body)
                        }
                        .foregroundColor(.blue)
                    }
                }
                #endif
                
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    if selectedConversation != nil {
                        // Show conversation menu when in a conversation
                        Menu {
                            Button(action: {
                                showingConversationSettings = true
                            }) {
                                Label("Conversation Settings", systemImage: "gear")
                            }

                            Button(action: {
                                // Export conversation action
                            }) {
                                Label("Export Chat", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(action: {
                                // Clear conversation action
                            }) {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Conversation Options")
                    } else {
                        // Show project settings when viewing conversations list
                        Button(action: {
                            showingProjectSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Project Settings")
                    }
                }
                #else
                ToolbarItem(placement: .navigation) {
                    if selectedConversation != nil {
                        // Show conversation menu when in a conversation
                        Menu {
                            Button(action: {
                                showingConversationSettings = true
                            }) {
                                Label("Conversation Settings", systemImage: "gear")
                            }

                            Button(action: {
                                // Export conversation action
                            }) {
                                Label("Export Chat", systemImage: "square.and.arrow.up")
                            }

                            Divider()

                            Button(action: {
                                // Clear conversation action
                            }) {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Conversation Options")
                    } else {
                        // Show project settings when viewing conversations list
                        Button(action: {
                            showingProjectSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .help("Project Settings")
                    }
                }
                #endif
            }
        }
        .onAppear {
            if let conversationId = conversation.id {
                conversationService.startListeningToMessages(conversationId: conversationId)
            }
        }
    }
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            iMessageHeaderView
            
            if projectService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredProjects) { project in
                            iMessageProjectRow(project: project)
                            .onTapGesture {
                                selectProject(project)
                            }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    // Pin/Unpin action
                                    Button(action: {
                                        togglePinProject(project)
                                    }) {
                                        VStack {
                                            Image(systemName: project.isPinned ? "pin.slash" : "pin")
                                                .font(.system(size: 20))
                                            Text(project.isPinned ? "Unpin" : "Pin")
                                                .font(.system(size: 12))
                                        }
                                        .foregroundColor(.white)
                                    }
                                    .tint(project.isPinned ? .orange : .blue)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    // Archive action
                                    if project.status != .archived {
                                        Button(action: {
                                            archiveProject(project)
                                        }) {
                                            VStack {
                                                Image(systemName: "archivebox")
                                                    .font(.system(size: 20))
                                                Text("Archive")
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundColor(.white)
                                        }
                                        .tint(.orange)
                                    } else {
                                        Button(action: {
                                            unarchiveProject(project)
                                        }) {
                                            VStack {
                                                Image(systemName: "tray.and.arrow.up")
                                                    .font(.system(size: 20))
                                                Text("Unarchive")
                                                    .font(.system(size: 12))
                                            }
                                            .foregroundColor(.white)
                                        }
                                        .tint(.green)
                                    }
                                }
                        }
                    }
                }
                .background(Color.black)
            }
        }
        .background(Color.black)
        .frame(minWidth: 280)
    }
    
    private var headerView: some View {
        HStack {
            Text("Lanna AI")
                .font(.title)
                .foregroundColor(.primary)
            
            Spacer()
            
            
            Button(action: { 
                #if os(macOS)
                isComposingProject = true
                selectedConversation = nil
                #else
                showingNewProject = true
                #endif
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
            }
            .buttonStyle(PlainButtonStyle())
            .help("New Project")
            
            Button(action: { showingAccountSettings = true }) {
                Image(systemName: "person.circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Account Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.secondary.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    private var searchView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
            
            TextField("Search spekt...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(.body)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var projectsList: some View {
        List(selection: $selectedProject) {
            ForEach(filteredProjects) { project in
                ProjectRowView(
                    project: project,
                    isEditMode: false,
                    onEdit: { _ in },
                    onDelete: { _ in }
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .onTapGesture {
                    selectProject(project)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    // Pin/Unpin action
                    Button(action: {
                        togglePinProject(project)
                    }) {
                        Image(systemName: project.isPinned ? "pin.slash" : "pin")
                            .foregroundColor(.white)
                    }
                    .tint(project.isPinned ? .orange : .blue)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    // Archive action
                    if project.status != .archived {
                        Button(action: {
                            archiveProject(project)
                        }) {
                            Image(systemName: "archivebox")
                                .foregroundColor(.white)
                        }
                        .tint(.orange)
                    } else {
                        Button(action: {
                            unarchiveProject(project)
                        }) {
                            Image(systemName: "tray.and.arrow.up")
                                .foregroundColor(.white)
                        }
                        .tint(.green)
                    }
                }
            }
        }
        .listStyle(SidebarListStyle())
        .scrollContentBackground(.hidden)
    }
    
    private var conversationsList: some View {
        VStack(spacing: 0) {
            // Header with Create Conversation button
            HStack {
                Text("Conversations")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Menu {
                    Button("Chat") {
                        Task {
                            await MainActor.run {
                                createBlankConversationAndNavigate()
                            }
                        }
                    }
                    Button("Voice (Realtime)") {
                        showingRealtimeMode = true
                    }
                    Button("Listen Mode") {
                        showingVoiceMemo = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .help("Conversation options")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.secondary.opacity(0.1)),
                alignment: .bottom
            )
            
            // Conversations list with iMessage styling
            if conversationService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConversations) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectConversation(conversation)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Delete conversation action
                                Button(action: {
                                    deleteConversation(conversation)
                                }) {
                                    VStack {
                                        Image(systemName: "trash")
                                            .font(.system(size: 20))
                                        Text("Delete")
                                            .font(.system(size: 12))
                                    }
                                    .foregroundColor(.white)
                                }
                                .tint(.red)
                            }
                            .contextMenu {
                                Button(action: {
                                    selectConversation(conversation)
                                }) {
                                    Label("Open Conversation", systemImage: "message")
                                }

                                Divider()

                                Button(role: .destructive, action: {
                                    deleteConversation(conversation)
                                }) {
                                    Label("Delete Conversation", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .background(Color.black)
            }
        }
    }
    
    private var detailView: some View {
        Group {
            if isComposingProject {
                ProjectComposeView { project, firstMessage in
                    Task {
                        do {
                            let projectId = try await projectService.createProject(
                                title: project.title,
                                description: project.description,
                                type: project.type
                            )
                            
                            // Create first conversation with message if provided
                            if let message = firstMessage, !message.isEmpty {
                                try await conversationService.createConversation(
                                    projectId: projectId,
                                    projectName: project.title,
                                    initialMessage: message
                                )
                            }
                            
                            isComposingProject = false
                        } catch {
                            print("Error creating project: \(error)")
                        }
                    }
                }
            } else if let selectedConversation = selectedConversation {
                // Show chat view when a conversation is selected (highest priority)
                Group {
                    #if os(iOS)
                    ChatMessagesView_iOS(
                        conversation: selectedConversation,
                        conversationService: conversationService,
                        captureRequest: Binding(
                            get: { pendingCaptureRequest },
                            set: { pendingCaptureRequest = $0 }
                        )
                    )
                    #else
                    ChatMessagesView(
                        conversation: selectedConversation,
                        conversationService: conversationService,
                        captureRequest: Binding(
                            get: { pendingCaptureRequest },
                            set: { pendingCaptureRequest = $0 }
                        )
                    )
                    #endif
                }
                .navigationTitle(selectedConversation.projectName ?? "Chat")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    print("🔍 ProjectsListView: Showing chat view for conversation: \(selectedConversation.id ?? "no-id")")
                }
            } else if let selectedProject = selectedProject {
                // Show conversations for the selected project
                if conversationService.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if conversationService.conversations.isEmpty {
                    VStack(spacing: 24) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        
                        VStack(spacing: 8) {
                            Text("No Conversations Yet")
                                .font(Typography.displayMedium)
                                .foregroundColor(.primary)
                            
                            Text("Start a new conversation in \(selectedProject.title)")
                                .font(.body)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button("Start Conversation") {
                            createBlankConversationAndNavigate()
                        }
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.blue)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.1))
                } else {
                    conversationsList
                }
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "folder")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    VStack(spacing: 8) {
                        Text("Lanna AI")
                            .font(Typography.displayMedium)
                            .foregroundColor(.primary)
                        
                        Text("Select a project to view conversations or start a new one")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
            }
        }
    }
    
    private func selectProject(_ project: Project) {
        print("🔍 Selecting project: \(project.title) (ID: \(project.id ?? "no-id"))")
        selectedProject = project
        selectedConversation = nil
        pendingCaptureRequest = nil
        
        // Navigate to conversations view
        currentView = .conversations(project)
        
        // Load conversations for this project
        print("🔍 Loading conversations for project: \(project.title)")
        if let projectId = project.id {
            conversationService.startListeningToConversations(projectId: projectId)
        } else {
            conversationService.startListeningToConversations()
        }
    }
    
    private func selectConversation(_ conversation: Conversation) {
        print("🔍 Selecting conversation: \(conversation.id ?? "no-id")")
        print("🔍 Project ID: \(conversation.projectId ?? "no-project-id")")
        selectedConversation = conversation
        
        // Navigate to chat view
        currentView = .chat(conversation)
        
        if let conversationId = conversation.id {
            print("🔍 Starting to listen to messages for conversation: \(conversationId)")
            conversationService.startListeningToMessages(conversationId: conversationId)
        } else {
            print("❌ Missing conversation ID")
        }
    }

    private func triggerCapture(_ type: CaptureActionType) {
        guard let conversation = activeConversationForCapture(), let conversationId = conversation.id else {
            captureMenuError = "Please open a conversation before starting \(type == .listen ? "Listen" : "Watch") Mode."
            showingCaptureMenuError = true
            return
        }
        captureMenuError = nil
        selectedConversation = conversation
        currentView = .chat(conversation)
        if let conversationId = conversation.id {
            conversationService.startListeningToMessages(conversationId: conversationId)
        }
        pendingCaptureRequest = CaptureRequest(id: UUID(), conversationId: conversationId, type: type)
    }

    private func activeConversationForCapture() -> Conversation? {
        if let selectedConversation {
            return selectedConversation
        }
        if case .chat(let conversation) = currentView {
            return conversation
        }
        return nil
    }
    
    private func createBlankConversationAndNavigate() {
        guard let selectedProject = selectedProject,
              let projectId = selectedProject.id else {
            print("❌ No selected project for creating conversation")
            return
        }
        
        Task {
            do {
                // Create a blank conversation
                let conversationId = try await conversationService.createConversation(
                    projectId: projectId,
                    projectName: selectedProject.title,
                    initialMessage: "" // Empty initial message
                )
                
                // Create a conversation object
                let newConversation = Conversation(
                    id: conversationId,
                    userId: Auth.auth().currentUser?.uid ?? "",
                    projectId: projectId,
                    projectName: selectedProject.title,
                    lastMessage: "",
                    lastMessageAt: Date(),
                    lastMessageTime: Date(),
                    messagesCount: 0,
                    updatedAt: Date(),
                    createdAt: Date(),
                    sharedContext: nil,
                    sharedDocuments: nil
                )
                
                // Navigate directly to chat view
                await MainActor.run {
                    selectedConversation = newConversation
                    currentView = .chat(newConversation)
                }
            } catch {
                print("❌ Error creating blank conversation: \(error)")
            }
        }
    }
    
    private func togglePinProject(_ project: Project) {
        Task {
            do {
                try await projectService.togglePinProject(project)
            } catch {
                print("❌ Error toggling pin for project: \(error)")
            }
        }
    }
    
    private func archiveProject(_ project: Project) {
        Task {
            do {
                try await projectService.archiveProject(project)
            } catch {
                print("❌ Error archiving project: \(error)")
            }
        }
    }
    
    private func unarchiveProject(_ project: Project) {
        Task {
            do {
                try await projectService.unarchiveProject(project)
            } catch {
                print("❌ Error unarchiving project: \(error)")
            }
        }
    }
    
    private func deleteConversation(_ conversation: Conversation) {
        Task {
            do {
                try await conversationService.deleteConversation(conversation)
                
                // If this was the selected conversation, clear the selection
                if selectedConversation?.id == conversation.id {
                    selectedConversation = nil
                    if let project = selectedProject {
                        currentView = .conversations(project)
                    } else {
                        currentView = .projects
                    }
                }
            } catch {
                print("❌ Error deleting conversation: \(error)")
            }
        }
    }
    
    private func signOut() {
        do {
            try authService.signOut()
            pendingCaptureRequest = nil
        } catch {
            print("Error signing out: \(error)")
        }
    }
}

struct ProjectRowView: View {
    let project: Project
    let isEditMode: Bool
    let onEdit: (Project) -> Void
    let onDelete: (Project) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: project.type.systemImage)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 20, height: 20)
                
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(project.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                HStack {
                    Spacer()
                    
                    Text(project.updatedAt, format: .dateTime.day().month().year())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isEditMode {
                HStack(spacing: 4) {
                    Button(action: { onEdit(project) }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Edit Project")
                    
                    Button(action: { onDelete(project) }) {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Delete Project")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

struct ProjectDetailView: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Image(systemName: project.type.systemImage)
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text(project.title)
                        .font(Typography.titleLarge)
                        .foregroundColor(.primary)
                    
                    Text(project.type.displayName)
                        .font(Typography.bodySmall)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(project.status.displayName)
                    .font(Typography.label)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, DS.spacingXS)
                    .background(Color(project.status.color))
                    .cornerRadius(DS.spacingXS)
            }
            
            Text(project.description)
                .font(Typography.bodyLarge)
                .foregroundColor(.primary)
            
            HStack {
                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text("Created")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                    Text(project.createdAt, format: .dateTime.day().month().year())
                        .font(Typography.bodySmall)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: DS.spacingXS) {
                    Text("Last Updated")
                        .font(Typography.caption)
                        .foregroundColor(.secondary)
                    Text(project.updatedAt, format: .dateTime.day().month().year())
                        .font(Typography.bodySmall)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
        }
        .padding(DS.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.gray.opacity(0.1))
    }
}

// MARK: - Conversation Mode Sheets

#if os(iOS)
private struct RealtimeModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            RealtimeChatView()
                .navigationTitle("Realtime Chat")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

private struct VoiceModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Text("Legacy Voice Mode")
                .navigationTitle("Voice Chat")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
#else
private struct RealtimeModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Realtime chat is currently available on iOS only.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Realtime Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct VoiceModeSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Image(systemName: "waveform")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Voice chat is currently available on iOS only.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Voice Chat")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
#endif

private struct VideoChatModeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isPreviewActive = false
    @State private var cameraStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @State private var microphoneStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    @State private var isRequestingPermissions = false
    @State private var showingPermissionAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VideoPreviewPlaceholder(isActive: isPreviewActive)
                    .frame(height: 260)

                VStack(alignment: .leading, spacing: 12) {
                    PermissionStatusRow(icon: "camera.fill", title: "Camera", isGranted: cameraStatus == .authorized)
                    PermissionStatusRow(icon: "mic.fill", title: "Microphone", isGranted: microphoneStatus == .authorized)

                    if !hasRequiredPermissions {
                        Text("Video chat needs access to your camera and microphone. Grant access so we can connect you with Lanna.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Text("Launch a video call experience directly from Lanna. This preview will evolve into a full video chat once camera streaming is enabled.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)

                if !hasRequiredPermissions {
                    Button(action: requestPermissions) {
                        Group {
                            if isRequestingPermissions {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Label("Enable Camera & Microphone", systemImage: "lock.open")
                                    .font(.headline)
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(14)
                    }
                    .disabled(isRequestingPermissions)
                }

                Button(action: togglePreview) {
                    Label(isPreviewActive ? "End Preview" : "Start Preview",
                          systemImage: isPreviewActive ? "video.slash.fill" : "video.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(isPreviewActive ? Color.red : hasRequiredPermissions ? Color.blue : Color.gray)
                        .cornerRadius(14)
                }
                .disabled(!hasRequiredPermissions)

                Spacer()
            }
            .padding()
            .navigationTitle("Video Chat Mode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Permissions Needed", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    #if os(iOS)
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    #endif
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Camera and microphone access are required to start video chat mode. Allow permissions in Settings and try again.")
            }
        }
        .onAppear(perform: refreshPermissions)
    }

    private var hasRequiredPermissions: Bool {
        cameraStatus == .authorized && microphoneStatus == .authorized
    }

    private func togglePreview() {
        guard hasRequiredPermissions else {
            showingPermissionAlert = true
            return
        }
        isPreviewActive.toggle()
    }

    private func refreshPermissions() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    private func requestPermissions() {
        guard !isRequestingPermissions else { return }
        isRequestingPermissions = true
        Task {
            let cameraGranted = await requestAccess(for: .video)
            let microphoneGranted = await requestAccess(for: .audio)
            await MainActor.run {
                isRequestingPermissions = false
                refreshPermissions()
                if !(cameraGranted && microphoneGranted) {
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func requestAccess(for mediaType: AVMediaType) async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: mediaType) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private struct VideoPreviewPlaceholder: View {
    let isActive: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(colors: [
                        Color.blue.opacity(0.3),
                        Color.purple.opacity(0.3)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            VStack(spacing: 12) {
                Image(systemName: isActive ? "video.fill" : "video")
                    .font(.system(size: 54))
                    .foregroundColor(.white)

                Text(isActive ? "Preview On" : "Camera Preview")
                    .font(.headline)
                    .foregroundColor(.white)
            }
        }
    }
}

private struct PermissionStatusRow: View {
    let icon: String
    let title: String
    let isGranted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isGranted ? .green : .orange)
                .frame(width: 28)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(isGranted ? .green : .orange)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.08))
        )
    }
}
