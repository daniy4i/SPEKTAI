# iPhone Port File Change Checklist

The tables below summarize every source/configuration asset currently in the repository and outline the adjustments or validations needed before implementing the iPhone port. Actions range from concrete refactors to scoped reviews when no change is expected but verification is required.

## Root Application Files

| File | iPhone Port Notes |
| --- | --- |
| `lannaappApp.swift` | Confirm Firebase configuration remains synchronous-safe on iPhone launch; evaluate whether an app or scene delegate is needed for push/background tasks; no UI refactor required. |
| `MainAppView.swift` | Revisit navigation orchestration for a single-window iPhone flow (replace `Group` with `NavigationStack` hierarchy, ensure scene transitions respect compact width); audit sheet stacking so multiple modal presentations do not conflict on iPhone. |
| `ContentView.swift` | Determine whether this debug-only entry point stays in the bundle; if retained, ensure safe-area padding and accessibility labels scale on small devices. |
| `DesignSystem.swift` | Validate spacing/typography tokens against Human Interface Guidelines; add compact-size overrides (e.g., reduced XL spacing, dynamic type variants) and ensure color references meet contrast on smaller displays. |
| `ProjectsListView.swift` | Major refactor: collapse multi-column layout to single-column navigation, replace desktop-style header with mobile toolbar, convert sheet-based modals to navigation links where appropriate, review capture/voice/video flows for compact presentation, and guard AV/camera availability. |
| `StoreKitConfig.swift` | Align paywall flow with in-app purchase policies for iPhone (update product identifiers, localized descriptions, and ensure `Configuration.storekit` sync). |
| `Configuration.storekit` | Update metadata for iPhone screenshots/testing groups; verify subscription group configuration and intro offers needed on iPhone. |
| `firestore.rules` & `firebase-storage.rules` | No platform-specific logic expected but run regression review for mobile access patterns discovered during port. |
| `lannaapp.entitlements` | Add or confirm iPhone capabilities (push notifications, background modes, audio, Bluetooth); ensure no iPad-only capabilities remain enabled unintentionally. |
| `lannaapp-Bridging-Header.h` | Verify HeyCyan/QCSDK availability in iPhone build, remove unused imports, and confirm the bridging header stays referenced by the iPhone target. |
| `Assets.xcassets` | Add missing @2x/@3x variants, provide iPhone launch screen storyboard or SwiftUI entry, and audit symbol sets for legibility in compact sizes. |
| `Preview Content` | Optional: trim platform-specific previews or add iPhone previews for key reusable views. |

## Shared Models (`Shared/Models`)

| File | iPhone Port Notes |
| --- | --- |
| `Project.swift`, `Conversation.swift`, `MediaItem.swift`, `ChatModels.swift`, `CaptureRequest.swift`, `PaidPlan.swift` | Data structures remain shared; confirm Codable mappings still align with any new iPhone-only properties (e.g., compact layout preferences). |
| `OnboardingModels.swift` | Ensure onboarding paging metadata supports portrait-first design (image ratios, copy length for smaller screens). |

## Shared Views – Global (`Shared/Views`)

| File | iPhone Port Notes |
| --- | --- |
| `OnboardingView.swift` | Tune spacing for compact width, ensure buttons remain reachable, and adopt `TabView`/`PageTabViewStyle` safe-area adjustments for edge-to-edge iPhone UI. |
| `SmartGlassesSetupView.swift` | Review column layout and large illustrations; provide stacked layout and scrollability for 5.4" screens. |
| `SmartGlassesMediaTransferView.swift` | Convert any multi-pane layout to stepper or modal flows; ensure file-picker integrations respect iPhone sandbox. |
| `PermissionsView.swift` | Audit permission copy/buttons to follow iPhone guidelines (link to Settings, use `UIApplication.openSettingsURLString`). |
| `SubscriptionView.swift` | Adapt pricing cards to vertical stacking, ensure purchase buttons are reachable, and align tint colors with iPhone paywall best practices. |
| `AccountSettingsView.swift`, `LoginView.swift`, `SignUpView.swift`, `ForgotPasswordView.swift` | Add `NavigationStack` wrappers for iPhone, adjust form widths, enable keyboard avoidance with `scrollDismissesKeyboard`, and ensure safe-area padding. |
| `ProjectComposeView.swift`, `EditProjectView.swift`, `NewProjectView.swift` | Refine navigation bar toolbars, convert popovers to sheets, and compress side-by-side sections into sequential forms. |
| `ProjectSelectorView.swift` | Scale grid/list selection for compact width, potentially switch to `List` with search for iPhone. |
| `MediaGalleryView.swift`, `ProjectMediaGalleryView.swift`, `Media/MediaItemView.swift` | Replace multi-column grids with adaptive `LazyVGrid` using one/two columns depending on width; ensure full-screen media viewer supports portrait. |
| `LannaInfoView.swift` | Validate copy length, adjust image scaling. |
| `Components/UsageRing.swift`, `Components/MicrophoneSelectionView.swift` | Ensure component sizing works within narrower margins; consider inline presentation within sheets. |
| `Audio/AudioPlayerView.swift` | Verify transport controls remain accessible with one-handed use; integrate haptic feedback. |
| `Chat/RealtimeChatView.swift` | Rebuild layout to integrate with iPhone navigation: embed conversation list within `NavigationStack`, ensure chat detail pushes onto stack, manage keyboard-safe area, and support transcript auto-scroll. |
| `Chat/ChatComponents.swift` | Update documentation and ensure exported components conform to iPhone-specific styles (e.g., adopt `List` row insets). |
| `Chat/Components/Conversations/ConversationRow.swift` | Tweak typography for compact width, add context menu alternatives using swipe actions. |
| `Chat/Components/Conversations/EmptyChatState.swift` | Scale illustrations to avoid truncation. |
| `Chat/Components/Messages/MessageBubble.swift`, `TypingIndicator.swift`, `MessageInput.swift`, `VideoMessageView.swift`, `AudioMessageView.swift`, `MarkdownText.swift` | Audit bubble sizing, align with iPhone safe areas, convert `ActionSheet` usage to `confirmationDialog`, ensure media players use `AVPlayerViewController` sheets, and respect dynamic type. |
| `Chat/Components/Messages/DocumentRow.swift` | Confirm layout fits in compact list style, add quick actions. |
| `Chat/Components/Settings/ProjectSettingsView.swift`, `ConversationSettingsView.swift` | Convert to sheet or push detail view with grouped `List`; ensure toggles fit within iPhone widths. |

## Shared Services (`Shared/Services`)

| File | iPhone Port Notes |
| --- | --- |
| `Firebase/Services/AuthService.swift`, `ProjectService.swift`, `ConversationService.swift` | No iPhone-specific code changes expected; ensure concurrency handling doesn’t block main thread during heavy navigation transitions. |
| `ChatService.swift`, `GPTRealtimeAPI.swift` | Confirm streaming APIs perform well on mobile networks; add connectivity monitoring for cellular fallback. |
| `AnalyticsService.swift` | Ensure event payloads include device form factor for experimentation. |
| `PurchaseService.swift` | Update StoreKit flow for iPhone (present purchase sheet via `StoreKit.Transaction` APIs, handle failed purchases gracefully). |
| `MediaService.swift`, `ProjectMediaService.swift` | Validate image/video compression for mobile capture; enforce photo library permissions. |
| `VoiceToTextService.swift`, `ListenModeRecorder.swift`, `MicrophoneSelectionService.swift` | Ensure permission prompts trigger on iPhone, add audio session category tuning for handset speaker/mic. |
| `WatchModeVideoService.swift`, `SmartGlassesService.swift`, `SmartGlassesTransferService.swift`, `HeadsetDetectionService.swift` | Review Bluetooth/background requirements, ensure bridging APIs operate in iOS environment, and handle limited multitasking gracefully. |
| `FirestoreService.swift` | Evaluate offline caching strategy for mobile usage. |

## iOS-Specific UI (`iOS/`)

| File | iPhone Port Notes |
| --- | --- |
| `LoginView_iOS.swift`, `SignUpView_iOS.swift`, `ForgotPasswordView_iOS.swift`, `AccountSettingsView_iOS.swift` | Replace `NavigationView` with `NavigationStack`, implement content scroll views for keyboard avoidance, and confirm form field sizing works on smaller screens. |
| `NewProjectView_iOS.swift`, `EditProjectView_iOS.swift` | Adapt two-column modal assumptions to stacked `Form` sections; integrate `toolbar` buttons for cancel/done. |
| `Views/ChatView_iOS.swift` | Primary compact redesign: integrate conversation list and detail into `NavigationSplitView` fallback or push-based `NavigationStack`, manage toolbar buttons (voice/video/capture) via `ToolbarItem` and `confirmationDialog`, ensure orientation support. |
| `Views/VoiceMemoView_iOS.swift` | Update to full-screen cover with gestures, confirm audio session usage; add waveform resizing for portrait. |
| `Views/WatchMode/WatchModeCaptureView.swift` | Ensure capture controls scale, replace any drag/drop gestures with tappable controls, and manage process sheets via `fullScreenCover`. |

## macOS Counterparts (`macOS/`)

| File | iPhone Port Notes |
| --- | --- |
| `LoginView_macOS.swift`, `SignUpView_macOS.swift`, `ForgotPasswordView_macOS.swift`, `AccountSettingsView_macOS.swift`, `NewProjectView_macOS.swift`, `EditProjectView_macOS.swift`, `Views/ChatView_macOS.swift`, `Views/VoiceMemoView_macOS.swift` | No direct changes for iPhone, but keep parity in shared resources and ensure new shared abstractions don’t break macOS builds; update conditional compilation flags if shared code moves. |

## watchOS & Other Targets

| Asset | iPhone Port Notes |
| --- | --- |
| `watchOS/` | Currently empty/placeholder; confirm that any shared logic remains unaffected when introducing iPhone conditionals. |
| `Glasses/` | Validate whether headers or sample projects exist; ensure they remain referenced correctly when building for iPhone if moved into new frameworks. |

## Vendor Integrations

| File | iPhone Port Notes |
| --- | --- |
| `Vendor/HeyCyan/QCCentralManager.m`, `.h` | Confirm the HeyCyan SDK is compiled for arm64 iPhone, audit bridging usage on iPhone vs. iPad, and update build phases for the new target. |

## Supporting Assets

| Asset | iPhone Port Notes |
| --- | --- |
| `ProjectsListView.swift` previews, other `.preview` providers | Add iPhone device previews to validate compact layout. |
| `StoreKit` test data | Establish iPhone-specific subscription sandbox testers. |
| `README`/Documentation (not present) | Recommend adding a section describing universal target setup once implemented. |

## Tracking Notes

- Any file flagged “verify only” should still have a quick smoke test on physical iPhone hardware.
- As components migrate from sheets/popovers to push navigation, update all related call sites (e.g., `ProjectsListView` → `ChatView_iOS`).
- Keep a running checklist in your project tracker referencing these file-level notes to ensure coverage during implementation.
