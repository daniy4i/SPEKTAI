//
//  ChatComponents.swift
//  lannaapp
//
//  Main entry point for all chat-related UI components
//  This file has been modularized - individual components are now in separate files
//

import SwiftUI
import AVFoundation
#if os(iOS)
import AVKit
#endif

// MARK: - Component Imports
// All chat components are now modularized into separate files for better maintainability

// Message Components
// - MarkdownText.swift
// - TypingIndicator.swift
// - MessageBubble.swift
// - MessageInput.swift (to be extracted)
// - AudioMessageView.swift (to be extracted)
// - VideoMessageView.swift (to be extracted)
// - MediaDisplayView.swift (to be extracted)

// Conversation Components
// - ConversationRow.swift
// - EmptyChatState.swift

// Settings Components
// - DocumentRow.swift
// - ProjectSettingsView.swift (to be extracted)
// - ConversationSettingsView.swift (to be extracted)

// MARK: - Extracted Components
// All major components have been successfully modularized:

// MARK: - Additional components that still need extraction
// VideoMessageView, MediaDisplayView, ProjectSettingsView, ConversationSettingsView

// MARK: - Preview
#if DEBUG
struct ChatComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TypingIndicator()
            MessageInput(text: .constant("Hello"), onSend: {}, isLoading: false)
        }
        .padding()
    }
}
#endif