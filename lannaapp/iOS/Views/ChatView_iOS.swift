//
//  ChatView_iOS.swift
//  lannaapp
//
//  Created by Kareem Dasilva on 8/31/25.
//

import SwiftUI

enum ChatTab: String, CaseIterable {
    case chat = "Chat"
    case media = "Media"
    
    var systemIcon: String {
        switch self {
        case .chat:
            return "message"
        case .media:
            return "photo.on.rectangle.angled"
        }
    }
}

struct ChatView_iOS: View {
    let project: Project?
    @StateObject private var conversationService = ConversationService()
    @State private var selectedConversation: Conversation?
    @State private var showingConversationsList = false
    @State private var showingNewConversation = false
    @State private var selectedTab: ChatTab = .chat
    @State private var captureRequest: CaptureRequest?
    @State private var conversationToDelete: Conversation?
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showingConversationSettings = false
    
    var body: some View {
        NavigationStack {
            Group {
                if let selectedConversation = selectedConversation {
                    conversationDetailView(for: selectedConversation)
                } else {
                    conversationsListView
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    if selectedConversation != nil {
                        Button("Back") {
                            selectedConversation = nil
                            conversationService.stopListening()
                        }
                        .font(Typography.label)
                        .foregroundColor(DS.primary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { 
                            AnalyticsService.shared.trackNewConversationCreated(platform: AnalyticsService.shared.currentPlatform)
                            showingNewConversation = true 
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(DS.primary)
                        }
                        .help("New Conversation")
                        
                        if selectedConversation != nil {
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
                    }
                }
#else
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingNewConversation = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(DS.primary)
                    }
                }
#endif
            }
        }
        .onAppear {
            if let projectId = project?.id {
                conversationService.startListeningToConversations(projectId: projectId)
            } else {
                conversationService.startListeningToConversations()
            }
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
    
    private func conversationDetailView(for conversation: Conversation) -> some View {
        VStack(spacing: 0) {
            // Tab Picker
            tabPickerView
            
            // Tab Content
            tabContentView(for: conversation)
        }
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
            ChatMessagesView_iOS(
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
        #endif
    }
    
    private var conversationsListView: some View {
        List(selection: $selectedConversation) {
            ForEach(filteredConversations) { conversation in
                ConversationRow(
                    conversation: conversation,
                    isSelected: selectedConversation?.id == conversation.id
                )
                .listRowBackground(Color.clear)
                .tag(conversation)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteConversation(conversation)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
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
        .listStyle(PlainListStyle())
        .background(DS.background)
        .onChange(of: selectedConversation) { newConversation in
            if let conversation = newConversation {
                AnalyticsService.shared.trackConversationSelected(platform: AnalyticsService.shared.currentPlatform)
                selectConversation(conversation)
            }
        }
        .overlay(
            Group {
                if filteredConversations.isEmpty && !conversationService.isLoading {
                    EmptyChatState(
                        projectName: project?.title,
                        onStartChat: { showingNewConversation = true }
                    )
                }
            }
        )
    }
    
    private var filteredConversations: [Conversation] {
        if let project = project {
            return conversationService.conversations.filter { $0.projectId == project.id }
        } else {
            return conversationService.conversations
        }
    }
    
    private func selectConversation(_ conversation: Conversation) {
        selectedConversation = conversation
        captureRequest = nil
        if let conversationId = conversation.id,
           let projectId = conversation.projectId {
            conversationService.startListeningToMessages(conversationId: conversationId)
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

struct ChatMessagesView_iOS: View {
    let conversation: Conversation
    @ObservedObject var conversationService: ConversationService
    @Binding var captureRequest: CaptureRequest?
    @State private var messageText = ""
    @StateObject private var listenRecorder = ListenModeRecorder()
    @State private var isUploadingListenNote = false
    @State private var isProcessingWatchNote = false
    @State private var captureErrorMessage: String?
    @State private var showingCaptureError = false
    @State private var showingWatchModeRecorder = false

    var body: some View {
        VStack(spacing: 0) {
            messagesArea
            if listenRecorder.isRecording || isUploadingListenNote || isProcessingWatchNote {
                captureStatusBar
            }
            messageInputArea
        }
        .background(DS.background)
        .alert("Capture Error", isPresented: $showingCaptureError, actions: {
            Button("OK", role: .cancel) { }
        }, message: {
            Text(captureErrorMessage ?? "An unexpected error occurred.")
        })
        .onChange(of: listenRecorder.errorMessage) { newValue in
            if let message = newValue {
                captureErrorMessage = message
                showingCaptureError = true
            }
        }
        .fullScreenCover(isPresented: $showingWatchModeRecorder) {
            WatchModeCaptureView { url in
                showingWatchModeRecorder = false
                Task { await handleCapturedVideo(url) }
            } onCancel: {
                showingWatchModeRecorder = false
            }
            .ignoresSafeArea()
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
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.spacingM) {
                    ForEach(conversationService.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if conversationService.isSendingMessage {
                        TypingIndicator()
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
            .onChange(of: conversationService.messages.last?.content) { _ in
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
                    Button(action: stopListenMode) {
                        Text("Stop & Save")
                            .font(Typography.caption)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Cancel") {
                    listenRecorder.cancelRecording()
                }
                .font(Typography.caption)
                .foregroundColor(.red)
                .buttonStyle(.borderless)
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

    private func startWatchMode() {
        guard conversation.id != nil else {
            captureErrorMessage = "Conversation not available."
            showingCaptureError = true
            return
        }
        guard !isProcessingWatchNote && !showingWatchModeRecorder else { return }
        showingWatchModeRecorder = true
    }

    private func handleCapturedVideo(_ originalURL: URL) async {
        guard let conversationId = conversation.id else {
            await MainActor.run {
                captureErrorMessage = "Conversation not available."
                showingCaptureError = true
            }
            return
        }

        await MainActor.run {
            isProcessingWatchNote = true
        }

        do {
            let compressedURL = try await WatchModeVideoService.compressVideo(at: originalURL)
            let duration = WatchModeVideoService.duration(of: compressedURL)
            let thumbnailURL = try? WatchModeVideoService.generateThumbnail(for: compressedURL)

            defer {
                try? FileManager.default.removeItem(at: originalURL)
                try? FileManager.default.removeItem(at: compressedURL)
                if let thumbnailURL {
                    try? FileManager.default.removeItem(at: thumbnailURL)
                }
            }

            try await conversationService.sendVideoMessage(
                conversationId: conversationId,
                videoFileURL: compressedURL,
                duration: duration,
                thumbnailFileURL: thumbnailURL
            )

            await MainActor.run {
                isProcessingWatchNote = false
            }
        } catch {
            await MainActor.run {
                isProcessingWatchNote = false
                captureErrorMessage = error.localizedDescription
                showingCaptureError = true
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
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
            if isProcessingWatchNote || showingWatchModeRecorder {
                captureErrorMessage = "Please wait for the current Watch Mode upload to finish."
                showingCaptureError = true
            } else {
                captureErrorMessage = nil
                startWatchMode()
            }
        }

        captureRequest = nil
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
