import Foundation
import FirebaseFirestore
import Combine

// MARK: - Media Service

@MainActor
class MediaService: ObservableObject {
    static let shared = MediaService()
    
    @Published var mediaItems: [MediaItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Media Management
    
    func startListeningToMedia(for conversationId: String) {
        isLoading = true
        errorMessage = nil
        
        db.collection("conversations")
            .document(conversationId)
            .collection("media")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to load media: \(error.localizedDescription)"
                        print("❌ [MediaService] Error loading media: \(error)")
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self.mediaItems = []
                        return
                    }
                    
                    self.mediaItems = documents.compactMap { document in
                        try? document.data(as: MediaItem.self)
                    }
                    
                    print("✅ [MediaService] Loaded \(self.mediaItems.count) media items")
                }
            }
    }
    
    func stopListening() {
        // Firestore listeners are automatically cleaned up when the view is deallocated
        mediaItems = []
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Media Operations
    
    func addMediaItem(_ mediaItem: MediaItem) async throws {
        do {
            try db.collection("conversations")
                .document(mediaItem.conversationId)
                .collection("media")
                .document(mediaItem.id)
                .setData(from: mediaItem)
            
            print("✅ [MediaService] Added media item: \(mediaItem.id)")
        } catch {
            print("❌ [MediaService] Error adding media item: \(error)")
            throw error
        }
    }
    
    func deleteMediaItem(_ mediaItem: MediaItem) async throws {
        do {
            try await db.collection("conversations")
                .document(mediaItem.conversationId)
                .collection("media")
                .document(mediaItem.id)
                .delete()
            
            print("✅ [MediaService] Deleted media item: \(mediaItem.id)")
        } catch {
            print("❌ [MediaService] Error deleting media item: \(error)")
            throw error
        }
    }
    
    // MARK: - Media Filtering
    
    func mediaItems(for type: MediaType) -> [MediaItem] {
        return mediaItems.filter { $0.type == type }
    }
    
    func mediaItemsByDate() -> [Date: [MediaItem]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: mediaItems) { mediaItem in
            calendar.dateInterval(of: .day, for: mediaItem.createdAt)?.start ?? mediaItem.createdAt
        }
        
        return grouped.mapValues { items in
            items.sorted { $0.createdAt > $1.createdAt }
        }
    }
    
    // MARK: - Mock Data for Testing
    
    func loadMockData() {
        mediaItems = MediaItem.mockMediaItems
        isLoading = false
        errorMessage = nil
    }
}

// MARK: - Media Extensions

extension MediaItem {
    var formattedFileSize: String {
        guard let fileSize = fileSize else { return "Unknown size" }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var formattedDuration: String {
        guard let duration = duration else { return "" }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "0:%02d", seconds)
        }
    }
    
    var displayTitle: String {
        return title ?? "Untitled \(type.displayName)"
    }
}
