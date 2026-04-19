//
//  ProjectMediaGalleryView.swift
//  lannaapp
//
//  Created by Claude on 01/23/2025.
//

import SwiftUI

struct ProjectMediaGalleryView: View {
    let project: Project
    @StateObject private var mediaService = ProjectMediaService()
    @State private var selectedMediaType: ProjectMediaType? = nil
    @State private var searchText = ""
    @State private var isRefreshing = false

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: DS.spacingM)
    ]

    var filteredMedia: [ProjectMediaItem] {
        var items = mediaService.mediaItems

        // Apply type filter
        if let selectedType = selectedMediaType {
            items = items.filter { $0.type == selectedType }
        }

        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter { item in
                item.fileName.localizedCaseInsensitiveContains(searchText) ||
                item.conversationName?.localizedCaseInsensitiveContains(searchText) == true ||
                item.messageContent?.localizedCaseInsensitiveContains(searchText) == true
            }
        }

        return items
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with summary
                if !mediaService.isLoading && mediaService.summary.totalCount > 0 {
                    mediaSummaryHeader
                }

                // Filter tabs
                if !mediaService.isLoading && !mediaService.mediaItems.isEmpty {
                    mediaTypeFilter
                }

                // Search bar
                if !mediaService.isLoading && !mediaService.mediaItems.isEmpty {
                    searchBar
                }

                // Content
                ZStack {
                    if mediaService.isLoading {
                        loadingView
                    } else if mediaService.mediaItems.isEmpty {
                        emptyStateView
                    } else if filteredMedia.isEmpty {
                        noResultsView
                    } else {
                        mediaGrid
                    }
                }
            }
            .navigationTitle("Project Media")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .refreshable {
                await refreshMedia()
            }
        }
        .onAppear {
            loadMedia()
        }
    }

    private var mediaSummaryHeader: some View {
        VStack(spacing: DS.spacingS) {
            HStack {
                VStack(alignment: .leading, spacing: DS.spacingXS) {
                    Text("\(mediaService.summary.totalCount) Items")
                        .font(Typography.titleMedium)
                        .foregroundColor(DS.textPrimary)

                    Text(mediaService.summary.formattedTotalSize)
                        .font(Typography.bodySmall)
                        .foregroundColor(DS.textSecondary)
                }

                Spacer()

                HStack(spacing: DS.spacingM) {
                    mediaSummaryItem(
                        count: mediaService.summary.audioCount,
                        icon: "waveform",
                        color: DS.primary,
                        label: "Audio"
                    )

                    mediaSummaryItem(
                        count: mediaService.summary.videoCount,
                        icon: "video.fill",
                        color: DS.secondary,
                        label: "Video"
                    )

                    mediaSummaryItem(
                        count: mediaService.summary.imageCount,
                        icon: "photo.fill",
                        color: DS.textSecondary,
                        label: "Images"
                    )
                }
            }
        }
        .padding(DS.spacingM)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .stroke(DS.textSecondary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, DS.spacingM)
        .padding(.top, DS.spacingS)
    }

    private func mediaSummaryItem(count: Int, icon: String, color: Color, label: String) -> some View {
        VStack(spacing: DS.spacingXS) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)

            Text("\(count)")
                .font(Typography.bodyMedium)
                .foregroundColor(DS.textPrimary)

            Text(label)
                .font(Typography.caption)
                .foregroundColor(DS.textSecondary)
        }
    }

    private var mediaTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.spacingM) {
                // All filter
                ProjectFilterChip(
                    title: "All",
                    count: mediaService.summary.totalCount,
                    isSelected: selectedMediaType == nil
                ) {
                    selectedMediaType = nil
                }

                // Type-specific filters
                ForEach(ProjectMediaType.allCases, id: \.self) { type in
                    let count = getCountForType(type)
                    if count > 0 {
                        ProjectFilterChip(
                            title: type.displayName,
                            count: count,
                            isSelected: selectedMediaType == type
                        ) {
                            selectedMediaType = selectedMediaType == type ? nil : type
                        }
                    }
                }
            }
            .padding(.horizontal, DS.spacingM)
        }
        .padding(.vertical, DS.spacingS)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DS.textSecondary)

            TextField("Search media...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .font(Typography.bodyMedium)

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DS.textSecondary)
                }
            }
        }
        .padding(DS.spacingM)
        .background(DS.surface)
        .cornerRadius(DS.cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius)
                .stroke(DS.textSecondary.opacity(0.1), lineWidth: 1)
        )
        .padding(.horizontal, DS.spacingM)
        .padding(.bottom, DS.spacingS)
    }

    private var loadingView: some View {
        VStack(spacing: DS.spacingL) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: DS.primary))
                .scaleEffect(1.2)

            Text("Loading project media...")
                .font(Typography.bodyMedium)
                .foregroundColor(DS.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: DS.spacingL) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(DS.textSecondary.opacity(0.5))

            VStack(spacing: DS.spacingS) {
                Text("No Media Found")
                    .font(Typography.titleMedium)
                    .foregroundColor(DS.textPrimary)

                Text("Start conversations and add voice memos, watch notes, or images to see them here.")
                    .font(Typography.bodyMedium)
                    .foregroundColor(DS.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh") {
                loadMedia()
            }
            .font(Typography.buttonText)
            .foregroundColor(.white)
            .padding(.horizontal, DS.spacingL)
            .padding(.vertical, DS.spacingM)
            .background(DS.primary)
            .cornerRadius(DS.cornerRadius)
        }
        .padding(DS.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsView: some View {
        VStack(spacing: DS.spacingL) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(DS.textSecondary.opacity(0.5))

            VStack(spacing: DS.spacingS) {
                Text("No Results Found")
                    .font(Typography.titleMedium)
                    .foregroundColor(DS.textPrimary)

                if !searchText.isEmpty {
                    Text("No media found for '\(searchText)'")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)
                } else if let type = selectedMediaType {
                    Text("No \(type.displayName.lowercased()) files found")
                        .font(Typography.bodyMedium)
                        .foregroundColor(DS.textSecondary)
                }
            }

            Button("Clear Filters") {
                searchText = ""
                selectedMediaType = nil
            }
            .font(Typography.buttonText)
            .foregroundColor(DS.primary)
            .padding(.horizontal, DS.spacingL)
            .padding(.vertical, DS.spacingS)
            .background(DS.primary.opacity(0.1))
            .cornerRadius(DS.cornerRadius)
        }
        .padding(DS.spacingXL)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediaGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: DS.spacingM) {
                ForEach(filteredMedia) { mediaItem in
                    MediaItemView(mediaItem: mediaItem)
                }
            }
            .padding(DS.spacingM)
        }
    }

    private func getCountForType(_ type: ProjectMediaType) -> Int {
        switch type {
        case .audio:
            return mediaService.summary.audioCount
        case .video:
            return mediaService.summary.videoCount
        case .image:
            return mediaService.summary.imageCount
        }
    }

    private func loadMedia() {
        guard let projectId = project.id else { return }
        Task {
            await mediaService.loadProjectMedia(projectId: projectId)
        }
    }

    private func refreshMedia() async {
        isRefreshing = true
        defer { isRefreshing = false }

        guard let projectId = project.id else { return }
        await mediaService.loadProjectMedia(projectId: projectId)
    }
}

// MARK: - Filter Chip Component

struct ProjectFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.spacingXS) {
                Text(title)
                    .font(Typography.caption)
                    .fontWeight(.medium)

                Text("\(count)")
                    .font(Typography.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.3) : DS.textSecondary.opacity(0.2))
                    )
            }
            .foregroundColor(isSelected ? .white : DS.textPrimary)
            .padding(.horizontal, DS.spacingM)
            .padding(.vertical, DS.spacingS)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? DS.primary : DS.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? DS.primary : DS.textSecondary.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}