import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct MediaGalleryView: View {
    let conversationId: String
    @StateObject private var mediaService = MediaService.shared
    @State private var selectedMediaItem: MediaItem?
    @State private var showingMediaDetail = false
    @State private var selectedFilter: MediaType? = nil
    
    private var filteredMediaItems: [MediaItem] {
        if let filter = selectedFilter {
            return mediaService.mediaItems(for: filter)
        }
        return mediaService.mediaItems
    }
    
    private var mediaByType: [MediaType: [MediaItem]] {
        Dictionary(grouping: filteredMediaItems) { $0.type }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                filterBar
                
                // Content
                if mediaService.isLoading {
                    loadingView
                } else if filteredMediaItems.isEmpty {
                    emptyStateView
                } else {
                    mediaGridView
                }
            }
            .navigationTitle("Media")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .onAppear {
                mediaService.startListeningToMedia(for: conversationId)
            }
            .onDisappear {
                mediaService.stopListening()
            }
            .sheet(isPresented: $showingMediaDetail) {
                if let mediaItem = selectedMediaItem {
                    MediaDetailView(mediaItem: mediaItem)
                }
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All filter
                FilterChip(
                    title: "All",
                    isSelected: selectedFilter == nil,
                    count: mediaService.mediaItems.count
                ) {
                    selectedFilter = nil
                }
                
                // Type filters
                ForEach(MediaType.allCases, id: \.self) { type in
                    let count = mediaService.mediaItems(for: type).count
                    if count > 0 {
                        FilterChip(
                            title: type.displayName,
                            isSelected: selectedFilter == type,
                            count: count,
                            icon: type.systemIcon,
                            color: type.color
                        ) {
                            selectedFilter = type
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
        .background(DS.background)
    }
    
    // MARK: - Media Grid
    
    private var mediaGridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(filteredMediaItems) { mediaItem in
                    MediaThumbnailView(mediaItem: mediaItem) {
                        selectedMediaItem = mediaItem
                        showingMediaDetail = true
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading media...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Media Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Generated images, videos, and other media will appear here")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let count: Int
    let icon: String?
    let color: Color?
    let action: () -> Void
    
    init(
        title: String,
        isSelected: Bool,
        count: Int,
        icon: String? = nil,
        color: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.count = count
        self.icon = icon
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? (color ?? .blue) : DS.surface)
            )
            .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Media Thumbnail View

struct MediaThumbnailView: View {
    let mediaItem: MediaItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Thumbnail or placeholder
                AsyncImage(url: URL(string: mediaItem.thumbnailUrl ?? mediaItem.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(mediaItem.type.color.opacity(0.2))
                        .overlay(
                            Image(systemName: mediaItem.type.systemIcon)
                                .font(.title2)
                                .foregroundColor(mediaItem.type.color)
                        )
                }
                .frame(height: 100)
                .clipped()
                .cornerRadius(8)
                
                // Media type overlay
                VStack {
                    HStack {
                        Spacer()
                        MediaTypeBadge(type: mediaItem.type)
                    }
                    Spacer()
                }
                .padding(4)
                
                // Duration overlay for video/audio
                if let duration = mediaItem.duration, (mediaItem.type == .video || mediaItem.type == .audio) {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(mediaItem.formattedDuration)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    .padding(4)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Media Type Badge

struct MediaTypeBadge: View {
    let type: MediaType
    
    var body: some View {
        Image(systemName: type.systemIcon)
            .font(.caption)
            .foregroundColor(.white)
            .padding(4)
            .background(type.color)
            .clipShape(Circle())
    }
}

// MARK: - Media Detail View

struct MediaDetailView: View {
    let mediaItem: MediaItem
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Media content
                    mediaContentView
                    
                    // Media info
                    mediaInfoView
                }
                .padding(16)
            }
            .navigationTitle(mediaItem.displayTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingShareSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [mediaItem.url])
            }
        }
    }
    
    private var mediaContentView: some View {
        Group {
            switch mediaItem.type {
            case .image, .gif:
                AsyncImage(url: URL(string: mediaItem.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            ProgressView()
                        )
                }
                .cornerRadius(12)
                
            case .video:
                // For now, show thumbnail - in a real app you'd use AVPlayerView
                AsyncImage(url: URL(string: mediaItem.thumbnailUrl ?? mediaItem.url)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                                Text("Video Preview")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        )
                }
                .cornerRadius(12)
                
            case .audio:
                VStack(spacing: 16) {
                    Image(systemName: "waveform")
                        .font(.system(size: 64))
                        .foregroundColor(mediaItem.type.color)
                    
                    Text("Audio File")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let duration = mediaItem.duration {
                        Text(mediaItem.formattedDuration)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(mediaItem.type.color.opacity(0.1))
                .cornerRadius(12)
                
            case .document:
                VStack(spacing: 16) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 64))
                        .foregroundColor(mediaItem.type.color)
                    
                    Text("Document")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(mediaItem.displayTitle)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(32)
                .background(mediaItem.type.color.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private var mediaInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let description = mediaItem.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Type")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mediaItem.type.displayName)
                        .font(.body)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Created")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(mediaItem.createdAt, style: .date)
                        .font(.body)
                        .fontWeight(.medium)
                }
            }
            
            if let dimensions = mediaItem.dimensions {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dimensions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(dimensions.displayString)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    if let fileSize = mediaItem.fileSize {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Size")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(mediaItem.formattedFileSize)
                                .font(.body)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(DS.surface)
        .cornerRadius(12)
    }
}

// MARK: - Share Sheet

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#elseif os(macOS)
struct ShareSheet: View {
    let items: [Any]
    var body: some View { EmptyView() }
}
#endif

#Preview {
    MediaGalleryView(conversationId: "preview")
        .onAppear {
            MediaService.shared.loadMockData()
        }
}
