//
//  ChatView_macOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI
import FirebaseAuth

struct ChatView_macOS: View {
    let project: Project?
    @StateObject private var conversationService = ConversationService()
    @State private var selectedConversation: Conversation?
    @State private var captureRequest: CaptureRequest?
    @State private var showingNewConversation = false
    @State private var selectedTab: ChatTab = .chat
    @State private var conversationToDelete: Conversation?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showingConversationSettings = false
    
    var body: some View {
        Group {
#if os(macOS)
            HSplitView {
                conversationsSidebar
                chatDetail
            }
#else
            NavigationSplitView {
                conversationsSidebar
            } detail: {
                chatDetail
            }
#endif
        }
        .onAppear {
            if let projectId = project?.id {
                conversationService.startListeningToConversations(projectId: projectId)
            } else {
                conversationService.startListeningToConversations()
            }
        }
        .onDisappear {
            conversationService.stopListening()
        }
        .sheet(isPresented: $showingNewConversation) {
            NewConversationView(project: project) { conversation in
                // Navigate to the conversation
                selectedConversation = conversation
            }
        }
        .sheet(isPresented: $showingConversationSettings) {
            if let selectedConversation = selectedConversation {
                ConversationSettingsView(conversation: selectedConversation)
            }
        }
        .alert("Delete Conversation", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                conversationToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let conversation = conversationToDelete {
                    performDelete(conversation)
                }
            }
        } message: {
            Text("Are you sure you want to delete this conversation? This action cannot be undone and will permanently delete all messages and media files.")
        }
        .overlay(
            Group {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()

                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: DS.primary))
                                .scaleEffect(1.2)

                            Text("Deleting conversation...")
                                .font(Typography.bodyMedium)
                                .foregroundColor(DS.textPrimary)
                        }
                        .padding(24)
                        .background(DS.surface)
                        .cornerRadius(DS.cornerRadius)
                        .shadow(color: DS.shadow, radius: 10, x: 0, y: 5)
                    }
                }
            }
        )
    }
    
    private var conversationsSidebar: some View {
        VStack(spacing: 0) {
            conversationsHeader
            conversationsList
        }
        .frame(minWidth: 250, maxWidth: 300)
        .background(DS.surface)
    }
    
    private var conversationsHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Conversations")
                    .font(Typography.titleMedium)
                    .foregroundColor(DS.textPrimary)
                
                if let project = project {
                    Text(project.title)
                        .font(Typography.caption)
                        .foregroundColor(DS.textSecondary)
                }
            }
            
            Spacer()
            
            Button(action: { 
                AnalyticsService.shared.trackNewConversationCreated(platform: AnalyticsService.shared.currentPlatform)
                showingNewConversation = true 
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.primary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("New Conversation")
        }
        .padding(DS.spacingM)
        .background(DS.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DS.textSecondary.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    private var conversationsList: some View {
        List(selection: $selectedConversation) {
            ForEach(filteredConversations) { conversation in
                ConversationRow(
                    conversation: conversation,
                    isSelected: selectedConversation?.id == conversation.id
                )
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .onTapGesture {
                    AnalyticsService.shared.trackConversationSelected(platform: AnalyticsService.shared.currentPlatform)
                    selectConversation(conversation)
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
        .listStyle(SidebarListStyle())
        .scrollContentBackground(.hidden)
    }
    
    private var filteredConversations: [Conversation] {
        if let project = project {
            return conversationService.conversations.filter { $0.projectId == project.id }
        } else {
            return conversationService.conversations
        }
    }
    
    private var chatDetail: some View {
        Group {
            if let selectedConversation = selectedConversation {
                conversationDetailView(for: selectedConversation)
            } else {
                EmptyChatState(
                    projectName: project?.title,
                    onStartChat: { showingNewConversation = true }
                )
            }
        }
    }
    
    private func conversationDetailView(for conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            // Header with ellipses menu
            chatHeaderView
            
            // Tab Picker
            tabPickerView
            
            // Tab Content
            tabContentView(for: conversation)
        }
    }
    
    private var chatHeaderView: some View {
        HStack {
            Spacer()
            
            Menu {
                Button(action: {
                    showingConversationSettings = true
                }) {
                    Label("Conversation Settings", systemImage: "gear")
                }
                
                Button(action: {
                    // Media gallery action
                    selectedTab = .media
                }) {
                    Label("Media Gallery", systemImage: "photo.on.rectangle.angled")
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
                    .foregroundColor(DS.primary)
            }
            .help("Chat Options")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(DS.background)
    }
    
    private var tabPickerView: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(ChatTab.allCases, id: \.self) { tab in
                HStack {
                    Image(systemName: tab.systemIcon)
                    Text(tab.rawValue)
                }
                .tag(tab)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private func tabContentView(for conversation: Conversation) -> some View {
        TabView(selection: $selectedTab) {
            ChatMessagesView(
                conversation: conversation,
                conversationService: conversationService,
                captureRequest: $captureRequest
            )
            .tag(ChatTab.chat)
            
            MediaGalleryView(conversationId: conversation.id ?? "")
                .tag(ChatTab.media)
        }
        #if os(iOS)
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        #else
        .tabViewStyle(DefaultTabViewStyle())
        #endif
    }
    
    private func selectConversation(_ conversation: Conversation) {
        print("🔍 ChatView_macOS: Selecting conversation: \(conversation.id ?? "no-id")")
        print("🔍 ChatView_macOS: Project ID: \(conversation.projectId ?? "no-project-id")")
        selectedConversation = conversation
        captureRequest = nil
        if let conversationId = conversation.id,
           let projectId = conversation.projectId {
            print("🔍 ChatView_macOS: Starting to listen to messages for conversation: \(conversationId)")
            conversationService.startListeningToMessages(conversationId: conversationId)
        } else {
            print("❌ ChatView_macOS: Missing conversation ID or project ID")
        }
    }

    private func deleteConversation(_ conversation: Conversation) {
        conversationToDelete = conversation
        showingDeleteConfirmation = true
    }

    private func performDelete(_ conversation: Conversation) {
        isDeleting = true

        Task {
            do {
                try await conversationService.deleteConversation(conversation)

                await MainActor.run {
                    // If the deleted conversation was selected, clear selection
                    if selectedConversation?.id == conversation.id {
                        selectedConversation = nil
                        conversationService.stopListening()
                    }

                    isDeleting = false
                    conversationToDelete = nil

                    print("✅ Conversation deleted successfully")
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    conversationToDelete = nil
                    print("❌ Failed to delete conversation: \(error)")

                    // TODO: Show error alert to user
                }
            }
        }
    }
}

struct ChatMessagesView: View {
    let conversation: Conversation
    @ObservedObject var conversationService: ConversationService
    @Binding var captureRequest: CaptureRequest?
    @State private var messageText = ""
    @State private var showingLannaInfo = false
    @StateObject private var listenRecorder = ListenModeRecorder()
    @State private var isUploadingListenNote = false
    @State private var isProcessingWatchNote = false
    @State private var captureErrorMessage: String?
    @State private var showingCaptureError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Debug header
            VStack(alignment: .leading, spacing: 4) {
                Text("ChatMessagesView Debug:")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Conversation ID: \(conversation.id ?? "nil")")
                    .font(.caption)
                    .foregroundColor(.red)
                Text("Messages count: \(conversationService.messages.count)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .padding(8)
            .background(Color.yellow.opacity(0.3))
            .cornerRadius(4)
            
            messagesArea
            if listenRecorder.isRecording || isUploadingListenNote || isProcessingWatchNote {
                captureStatusBar
            }
            messageInputArea
        }
        .background(DS.background)
        .sheet(isPresented: $showingLannaInfo) {
            if let project = getProjectFromConversation() {
                LannaInfoView(project: project)
            }
        }
        .onAppear {
            print("🔍 ChatMessagesView: Appeared for conversation: \(conversation.id ?? "no-id")")
            print("🔍 ChatMessagesView: Messages count: \(conversationService.messages.count)")
        }
        .alert("Capture Error", isPresented: $showingCaptureError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(captureErrorMessage ?? "An unexpected error occurred.")
        }
        .onChange(of: listenRecorder.errorMessage) { newValue in
            if let message = newValue {
                captureErrorMessage = message
                showingCaptureError = true
            }
        }
        .onAppear(perform: processCaptureRequestIfNeeded)
        .onChange(of: captureRequest?.id) { _ in
            processCaptureRequestIfNeeded()
        }
        .onDisappear {
            if let request = captureRequest,
               let conversationId = conversation.id,
               request.conversationId == conversationId {
                captureRequest = nil
            }
        }
    }
    
    private func getProjectFromConversation() -> Project? {
        // Create a mock project from conversation info
        return Project(
            title: conversation.projectName ?? "General Chat",
            description: "Creative project with Spekt AI",
            createdAt: conversation.createdAt,
            updatedAt: conversation.updatedAt,
            ownerUid: conversation.userId,
            type: .general,
            status: .inProgress,
            coverImage: nil,
            activeConversationId: conversation.id,
            conversationsCount: 1,
            isPinned: false
        )
    }
    
    private var chatHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                if let projectName = conversation.projectName {
                    Text(projectName)
                        .font(Typography.titleSmall)
                        .foregroundColor(DS.textPrimary)
                } else {
                    Text("General Chat")
                        .font(Typography.titleSmall)
                        .foregroundColor(DS.textPrimary)
                }
                
                Text("\(conversation.messagesCount) messages")
                    .font(Typography.caption)
                    .foregroundColor(DS.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingLannaInfo = true }) {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(DS.textSecondary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Spekt Info")
        }
        .padding(DS.spacingM)
        .background(DS.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DS.textSecondary.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.spacingM) {
                    // Debug information
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Debug Info:")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Messages count: \(conversationService.messages.count)")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Conversation ID: \(conversation.id ?? "nil")")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Is loading: \(conversationService.isLoading ? "true" : "false")")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.3))
                    .cornerRadius(8)
                    
                    ForEach(conversationService.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if conversationService.isSendingMessage {
                        TypingIndicator()
                    }
                    
                    // Show empty state if no messages
                    if conversationService.messages.isEmpty && !conversationService.isLoading {
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No messages yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Start a conversation with Spekt AI")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                }
                .padding(DS.spacingM)
            }
            .onChange(of: conversationService.messages.count) { _ in
                if let lastMessage = conversationService.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var messageInputArea: some View {
        MessageInput(
            text: $messageText,
            onSend: sendMessage,
            isLoading: conversationService.isSendingMessage || isUploadingListenNote || isProcessingWatchNote
        )
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DS.textSecondary.opacity(0.1)),
            alignment: .top
        )
    }

    private var captureStatusBar: some View {
        VStack(alignment: .leading, spacing: DS.spacingS) {
            if listenRecorder.isRecording {
                HStack {
                    Label("Recording…", systemImage: "waveform")
                        .foregroundColor(DS.primary)
                        .font(Typography.caption)
                    Spacer()
                    Text(formatDuration(listenRecorder.elapsedTime))
                        .font(Typography.caption)
                        .foregroundColor(DS.textSecondary)
                    Button("Stop & Save", action: stopListenMode)
                        .buttonStyle(.borderedProminent)
                }
                Button("Cancel", role: .cancel) {
                    listenRecorder.cancelRecording()
                }
                .font(Typography.caption)
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            } else if isUploadingListenNote {
                HStack(spacing: DS.spacingS) {
                    ProgressView()
                    Text("Saving voice note…")
                        .font(Typography.caption)
                        .foregroundColor(DS.textSecondary)
                    Spacer()
                }
            } else if isProcessingWatchNote {
                HStack(spacing: DS.spacingS) {
                    ProgressView()
                    Text("Processing watch note…")
                        .font(Typography.caption)
                        .foregroundColor(DS.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, DS.spacingM)
        .padding(.vertical, DS.spacingS)
        .background(DS.background)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(DS.textSecondary.opacity(0.1)),
            alignment: .top
        )
    }

    private func startListenMode() {
        guard conversation.id != nil else {
            captureErrorMessage = "Conversation not available."
            showingCaptureError = true
            return
        }
        guard !listenRecorder.isRecording else { return }
        Task { await listenRecorder.startRecording() }
    }

    private func stopListenMode() {
        guard let conversationId = conversation.id else {
            captureErrorMessage = "Conversation not available."
            showingCaptureError = true
            return
        }
        guard let result = listenRecorder.stopRecording() else {
            captureErrorMessage = "No recording in progress."
            showingCaptureError = true
            return
        }
        isUploadingListenNote = true
        Task {
            do {
                try await conversationService.sendAudioMessage(
                    conversationId: conversationId,
                    fileURL: result.url,
                    duration: result.duration
                )
                try? FileManager.default.removeItem(at: result.url)
                await MainActor.run {
                    self.isUploadingListenNote = false
                }
            } catch {
                try? FileManager.default.removeItem(at: result.url)
                await MainActor.run {
                    self.isUploadingListenNote = false
                    captureErrorMessage = error.localizedDescription
                    showingCaptureError = true
                }
            }
        }
    }

    private func informWatchModeUnavailable() {
        captureErrorMessage = "Watch Mode recording is currently supported on iOS devices."
        showingCaptureError = true
    }

    private func processCaptureRequestIfNeeded() {
        guard let request = captureRequest,
              let conversationId = conversation.id,
              request.conversationId == conversationId else { return }

        switch request.type {
        case .listen:
            if listenRecorder.isRecording || isUploadingListenNote {
                captureErrorMessage = "Finish the current Listen Mode before starting another one."
                showingCaptureError = true
            } else {
                captureErrorMessage = nil
                startListenMode()
            }
        case .watch:
            informWatchModeUnavailable()
        }

        captureRequest = nil
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func sendMessage() {
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, let conversationId = conversation.id else { return }
        
        AnalyticsService.shared.trackMessageSent(platform: AnalyticsService.shared.currentPlatform)
        messageText = ""
        
        let startTime = Date()
        
        Task {
            do {
                try await conversationService.sendMessage(
                    conversationId: conversationId,
                    content: content,
                    role: .user
                )
                
                // Simulate AI response
                try await conversationService.sendAIResponse(
                    conversationId: conversationId,
                    userMessage: content
                )
                
                let responseTime = Date().timeIntervalSince(startTime)
                AnalyticsService.shared.trackMessageReceived(platform: AnalyticsService.shared.currentPlatform, responseTime: responseTime)
            } catch {
                print("Error sending message: \(error)")
                AnalyticsService.shared.trackError(platform: AnalyticsService.shared.currentPlatform, error: error.localizedDescription, context: "message_sending")
            }
        }
    }
}

struct NewConversationView: View {
    let project: Project?
    let onConversationCreated: ((Conversation) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var conversationService = ConversationService()
    @State private var initialMessage = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    
    init(project: Project?, onConversationCreated: ((Conversation) -> Void)? = nil) {
        self.project = project
        self.onConversationCreated = onConversationCreated
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DS.spacingL) {
                VStack(spacing: DS.spacingM) {
                    Text("New Conversation")
                        .font(Typography.displayMedium)
                        .foregroundColor(DS.textPrimary)
                    
                    if let project = project {
                        Text("Start chatting about \(project.title)")
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textSecondary)
                    } else {
                        Text("Start a new conversation with Spekt AI")
                            .font(Typography.bodyMedium)
                            .foregroundColor(DS.textSecondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: DS.spacingS) {
                    Text("What would you like to discuss?")
                        .font(Typography.label)
                        .foregroundColor(DS.textPrimary)
                    
                    TextField("Ask a question or describe what you need help with...", text: $initialMessage, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(Typography.bodyMedium)
                        .lineLimit(3...6)
                }
                
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.error)
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
                    
                    Button(action: createConversation) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isLoading ? "Creating..." : "Create Conversation")
                                .font(Typography.buttonText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.spacingM)
                        .background(DS.primary)
                        .foregroundColor(.white)
                        .cornerRadius(DS.cornerRadius)
                    }
                    .disabled(isLoading)
                }
                
                Spacer()
            }
            .padding(DS.spacingXL)
            .background(DS.background)
            .frame(minWidth: 400, minHeight: 300)
            .navigationTitle("New Conversation")
        }
    }
    
    private func createBlankConversation() {
        guard let projectId = project?.id else { return }
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let conversationId = try await conversationService.createConversation(
                    projectId: projectId,
                    projectName: project?.title,
                    initialMessage: "" // Empty initial message for blank conversation
                )
                
                await MainActor.run {
                    // Create a conversation object to pass to the callback
                    let newConversation = Conversation(
                        id: conversationId,
                        userId: Auth.auth().currentUser?.uid ?? "",
                        projectId: projectId,
                        projectName: project?.title,
                        lastMessage: "",
                        lastMessageAt: Date(),
                        lastMessageTime: Date(),
                        messagesCount: 0,
                        updatedAt: Date(),
                        createdAt: Date(),
                        sharedContext: nil,
                        sharedDocuments: nil
                    )
                    
                    // Call the callback to navigate to the chat view
                    onConversationCreated?(newConversation)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func createConversation() {
        let message = initialMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                guard let projectId = project?.id else {
                    throw NSError(domain: "ProjectError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Project ID is required"])
                }
                
                let conversationId = try await conversationService.createConversation(
                    projectId: projectId,
                    projectName: project?.title,
                    initialMessage: message
                )
                
                // Only send AI response if there's an initial message
                if !message.isEmpty {
                    try await conversationService.sendAIResponse(
                        conversationId: conversationId,
                        userMessage: message
                    )
                }
                
                await MainActor.run {
                    // Create a conversation object to pass to the callback
                    let newConversation = Conversation(
                        id: conversationId,
                        userId: Auth.auth().currentUser?.uid ?? "",
                        projectId: projectId,
                        projectName: project?.title,
                        lastMessage: message,
                        lastMessageAt: Date(),
                        lastMessageTime: Date(),
                        messagesCount: message.isEmpty ? 0 : 1,
                        updatedAt: Date(),
                        createdAt: Date(),
                        sharedContext: nil,
                        sharedDocuments: nil
                    )
                    
                    // Call the callback to navigate to the chat view
                    onConversationCreated?(newConversation)
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
