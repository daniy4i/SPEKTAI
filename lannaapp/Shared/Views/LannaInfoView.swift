import SwiftUI

struct LannaInfoView: View {
    let project: Project
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Agent Profile Section
                VStack(spacing: 20) {
                    // Agent Avatar
                    Circle()
                        .fill(DS.primary)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Text("A")
                                .font(.system(size: 48, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    // Agent Info
                    VStack(spacing: 8) {
                        Text("Lanna")
                            .font(Typography.titleLarge)
                            .fontWeight(.bold)
                            .foregroundColor(DS.textPrimary)
                        
                        Text("AI Creative Agent")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(DS.textSecondary)
                        
                        Text("Working on \(project.title)")
                            .font(Typography.bodyMedium)
                            .foregroundStyle(DS.textSecondary)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 40)
                .padding(.bottom, 50)
                
                // Primary Action Buttons (Call/Video style)
                HStack(spacing: 60) {
                    // Voice Call Button
                    VStack(spacing: 12) {
                        Button {
                            startVoiceCall()
                        } label: {
                            Circle()
                                .fill(.green)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "phone.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Text("Call")
                            .font(Typography.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                    
                    // Video Call Button  
                    VStack(spacing: 12) {
                        Button {
                            startVideoCall()
                        } label: {
                            Circle()
                                .fill(DS.primary)
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                )
                        }
                        .buttonStyle(.plain)
                        
                        Text("FaceTime")
                            .font(Typography.caption)
                            .foregroundStyle(DS.textSecondary)
                    }
                }
                .padding(.bottom, 40)
                
                Spacer()
                
                // Secondary Actions (iPhone style)
                VStack(spacing: 0) {
                    ActionRow(
                        icon: "info.circle",
                        title: "Info",
                        action: showInfo
                    )
                    
                    ActionRow(
                        icon: "location",
                        title: "Share My Location",
                        action: shareLocation
                    )
                    
                    ActionRow(
                        icon: "photo",
                        title: "Media",
                        action: showMedia,
                        showBadge: true,
                        badgeCount: 12
                    )
                    
                    ActionRow(
                        icon: "link",
                        title: "Links",
                        action: showLinks,
                        showBadge: true,
                        badgeCount: 3
                    )
                }
                .background(DS.surface)
                .clipShape(RoundedRectangle(cornerRadius: DS.spacingS))
                .padding(.horizontal, DS.spacingM)
                .padding(.bottom, 40)
            }
            .background(DS.background)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.primary)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DS.primary)
                }
                #endif
            }
        }
    }
    
    // MARK: - Actions
    
    private func startVoiceCall() {
        print("Starting voice call with Lanna")
    }
    
    private func startVideoCall() {
        print("Starting video call with Lanna")
    }
    
    private func showInfo() {
        print("Show agent info")
    }
    
    private func shareLocation() {
        print("Share location")
    }
    
    private func showMedia() {
        print("Show media")
    }
    
    private func showLinks() {
        print("Show links")
    }
}

struct ActionRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    var showBadge: Bool = false
    var badgeCount: Int = 0
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(DS.primary)
                    .frame(width: 24, height: 24)
                
                // Title
                Text(title)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(DS.textPrimary)
                
                Spacer()
                
                // Badge
                if showBadge && badgeCount > 0 {
                    Text("\(badgeCount)")
                        .font(Typography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.textSecondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(.clear)
                .contentShape(Rectangle())
        )
        
        // Separator
        if title != "Links" { // Don't show separator for last item
            Rectangle()
                .fill(DS.textSecondary.opacity(0.2))
                .frame(height: 0.5)
                .padding(.leading, 56)
        }
    }
}

#Preview {
    LannaInfoView(project: Project(
        title: "Design Brief",
        description: "Creative project",
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