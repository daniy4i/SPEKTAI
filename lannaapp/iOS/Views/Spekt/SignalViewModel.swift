//
//  SignalViewModel.swift
//  lannaapp
//
//  MVVM ViewModel for the Signal (AI Identity) screen.
//  Owns all async operations: memory CRUD, patterns load, preferences save.
//  Optimistic updates keep the UI responsive; server errors are silent
//  (UI state is already correct from the optimistic write).
//

import SwiftUI

// MARK: - State Enums

enum LoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

enum SaveState: Equatable {
    case idle
    case saving
    case saved
    case failed(String)
}

// MARK: - ViewModel

@MainActor
final class SignalViewModel: ObservableObject {

    // MARK: Data
    @Published var memories      : [SpektMemory]  = []
    @Published var patterns      : UsagePattern?  = nil

    // MARK: Load / Save States
    @Published var memoriesState : LoadState = .idle
    @Published var patternsState : LoadState = .idle
    @Published var prefsSaveState: SaveState = .idle

    // MARK: Sheet / Dialog Triggers
    @Published var showAddMemory    = false
    @Published var showResetConfirm = false

    // MARK: Add Memory Form
    @Published var addMemoryText  = ""
    @Published var isAddingMemory = false

    // MARK: Dependencies
    private let api   = SpektAPI.shared
    private let prefs = PreferencesStore.shared

    // MARK: - Computed

    var memoriesCount: Int { memories.count }
    var pinnedCount  : Int { memories.filter(\.isPinned).count }

    var effectivePatterns: UsagePattern { patterns ?? .mock }

    // MARK: - Load

    func loadAll() async {
        async let mems : Void = loadMemories()
        async let pats : Void = loadPatterns()
        await mems
        await pats
    }

    func loadMemories() async {
        guard memoriesState != .loading else { return }
        memoriesState = .loading
        do {
            let result = try await api.fetchMemories()
            withAnimation(SpektTheme.Motion.springDefault) {
                memories      = result.sorted { $0.isPinned && !$1.isPinned }
                memoriesState = .loaded
            }
        } catch {
            memoriesState = .failed(error.localizedDescription)
            memories      = SpektMemory.mocks   // graceful fallback
        }
    }

    func loadPatterns() async {
        guard patternsState != .loading else { return }
        patternsState = .loading
        do {
            patterns      = try await api.fetchPatterns()
            patternsState = .loaded
        } catch {
            patternsState = .failed(error.localizedDescription)
            patterns      = .mock               // graceful fallback
        }
    }

    /// Force-reload memories even if previously loaded/failed.
    func retryMemories() async {
        memoriesState = .idle
        await loadMemories()
    }

    /// Force-reload patterns even if previously loaded/failed.
    func retryPatterns() async {
        patternsState = .idle
        await loadPatterns()
    }

    // MARK: - Memory CRUD

    /// Optimistic add: inserts immediately, then syncs to server.
    func submitAddMemory() async {
        let text = addMemoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isAddingMemory = true

        // Optimistic insert
        let optimistic = SpektMemory(
            id: UUID().uuidString,
            content: text,
            timestamp: Date(),
            isPinned: false
        )
        withAnimation(SpektTheme.Motion.springDefault) {
            memories.insert(optimistic, at: 0)
        }
        addMemoryText  = ""
        showAddMemory  = false
        isAddingMemory = false

        // Background sync — replace optimistic ID with server ID if needed
        do {
            let confirmed = try await api.addMemory(text)
            if let idx = memories.firstIndex(where: { $0.id == optimistic.id }) {
                memories[idx] = confirmed
            }
        } catch {
            // Keep optimistic copy — it's already visible
        }
    }

    /// Optimistic delete.
    func deleteMemory(_ memory: SpektMemory) {
        withAnimation(SpektTheme.Motion.springDefault) {
            memories.removeAll { $0.id == memory.id }
        }
        Task { try? await api.deleteMemory(id: memory.id) }
    }

    /// Optimistic pin toggle, re-sorts pinned to top.
    func togglePin(_ memory: SpektMemory) {
        guard let idx = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        let newPinned = !memories[idx].isPinned
        withAnimation(SpektTheme.Motion.springDefault) {
            memories[idx].isPinned = newPinned
            memories.sort { $0.isPinned && !$1.isPinned }
        }
        #if os(iOS)
        HapticEngine.impact(.light)
        #endif
        Task { try? await api.pinMemory(id: memory.id, pinned: newPinned) }
    }

    /// Clears all memories locally and on server.
    func resetIdentity() async {
        withAnimation(SpektTheme.Motion.springDefault) {
            memories = []
            showResetConfirm = false
        }
        #if os(iOS)
        HapticEngine.impact(.medium)
        #endif
        try? await api.deleteAllMemories()
    }

    // MARK: - Preferences

    func savePreferences() async {
        guard prefsSaveState != .saving else { return }
        prefsSaveState = .saving

        let payload = PreferencesPayload(
            voiceTone  : prefs.voiceTone,
            style      : prefs.style,
            format     : prefs.format,
            language   : prefs.language,
            detailLevel: prefs.detailLevel
        )
        do {
            try await api.savePreferences(payload)
            prefsSaveState = .saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
                if self?.prefsSaveState == .saved { self?.prefsSaveState = .idle }
            }
        } catch {
            prefsSaveState = .failed(error.localizedDescription)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.prefsSaveState = .idle
            }
        }
    }
}
