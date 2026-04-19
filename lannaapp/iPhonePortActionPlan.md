# iPhone Port Action Plan

This document outlines the preparatory work required before implementation begins. The focus is on the three immediate workstreams agreed upon: (1) cataloging platform-specific code paths, (2) wireframing compact-width UI flows, and (3) updating the project configuration to support both iPad and iPhone builds.

## Phase 1 – Catalog Platform-Specific Code Paths

### Objectives
- Build a comprehensive inventory of all platform-conditional logic and files to understand reuse and divergence across targets.
- Identify shared modules in `Shared/` that require adaptation for iPhone and note any missing abstractions.

### Tasks
1. **Structure Survey**: Map all platform folders (`iOS/`, `iPadOS/`, `macOS/`, `watchOS/`, `Shared/`, `Vendor/`) noting view, service, and configuration files; log findings in a structured spreadsheet or Notion database.
2. **Conditional Compilation Audit**: Use `rg` to locate `#if os(...)`, `#if targetEnvironment`, and platform-specific imports across the codebase; record occurrences with file references and purpose summaries.
3. **UI Component Pass**: For each SwiftUI view in `Shared/Views` and `iOS/Views`, document layout assumptions (size classes, device-specific modifiers) and flag components that assume regular width or rely on popovers/split views.
4. **Service Layer Review**: Inspect `Shared/Services`, `Shared/Utils`, and `Vendor/` for APIs that may behave differently on iPhone (e.g., background tasks, notifications, StoreKit); capture any entitlements or Info.plist dependencies.
5. **Dependency Matrix**: Produce a matrix showing which modules/classes are reused vs. duplicated per platform, highlighting gaps where shared abstractions should be introduced before porting.

### Deliverables
- Inventory spreadsheet (or Notion page) with platform-specific file listings and conditional logic notes.
- Dependency matrix indicating reuse level (Shared-only, iPad-only, iOS-only, etc.).
- Risk log capturing code areas with high divergence or missing iPhone equivalents.

### Owners & Timing
- Engineering lead for audit; estimated 1–2 working days with assistance from feature owners for clarification.

## Phase 2 – Wireframe Compact-Width UI Flows

### Objectives
- Define the end-to-end user journeys for iPhone, ensuring parity with existing iPad functionality while accommodating compact width constraints.
- Surface UX gaps early (navigation model, settings access, modal flows) before development.

### Tasks
1. **Screen Inventory**: Compile current user-facing screens from `MainAppView.swift`, `ProjectsListView.swift`, `ContentView.swift`, and feature-specific views in `iOS/`; document their purpose and entry points.
2. **User Flow Mapping**: Translate existing iPad flows into linear sequences suitable for single-column navigation; produce low-fidelity flow charts for core journeys (onboarding, project creation, editing, account settings).
3. **Layout Exploration**: For each screen, draft wireframes covering portrait and landscape compact widths. Address replacements for iPad-specific UI (split views, inspectors, popovers) with alternatives like tab bars, navigation stacks, sheets, or bottom drawers.
4. **Interaction Audit**: Identify interactions relying on multi-window, drag-and-drop, or pointer support; propose iPhone-friendly gestures or fallback patterns.
5. **Design Review Loop**: Run wireframes through design review with stakeholders; iterate based on feedback and document decisions impacting implementation (e.g., new components to add to `DesignSystem.swift`).

### Deliverables
- Wireframe set (Figma or equivalent) covering all primary flows in portrait/landscape compact width.
- Updated user flow diagrams and narrative notes for each journey.
- UX decision log outlining adaptations from iPad to iPhone experiences.

### Owners & Timing
- Product design lead with engineering partner; estimated 3–4 working days including review cycles.

## Phase 3 – Update Project Configuration for Dual iPad/iPhone Builds

### Objectives
- Ensure the Xcode project cleanly supports both iPad and iPhone deployments with shared code where feasible.
- Prepare build settings, entitlements, and assets for iPhone implementation work.

### Tasks
1. **Project Audit**: Open the `lannaapp.xcodeproj` (or workspace) in the `iOS/` directory; document current targets, schemes, build configurations, and deployment targets. Confirm whether a universal target already exists or if a new iPhone-specific target is required.
2. **Target Strategy Proposal**: Decide between a single universal target vs. separate iPad/iPhone targets. Outline pros/cons (shared bundle identifier, conditional resources, feature flags) and secure sign-off.
3. **Build Settings Plan**: List required adjustments (`IPHONEOS_DEPLOYMENT_TARGET`, `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME`, `INFOPLIST_KEY_UISupportedInterfaceOrientations`, etc.). Identify xcconfig additions if configuration files will be used for environment parity.
4. **Resource Preparation**: Inventory assets in `Assets.xcassets` to ensure `@2x`/`@3x` variants and iPhone-specific launch screens. Create to-do list for missing resources (screenshots, marketing images, localized strings).
5. **Entitlements & Capability Review**: Cross-check `lannaapp.entitlements`, notification/StoreKit capabilities, and any App Extensions to confirm compatibility with iPhone. Plan updates to provisioning profiles and signing settings.
6. **Automation & CI Checklist**: Outline required CI pipeline updates (fastlane lanes, TestFlight uploads, beta testing groups) once the configuration changes are applied.

### Deliverables
- Configuration change proposal document with annotated screenshots or tables from Xcode.
- Checklist of required build setting updates and asset gaps.
- CI/CD update plan covering build, test, and distribution impacts.

### Owners & Timing
- iOS engineering lead with DevOps support; estimated 2–3 working days including review.

## Cross-Phase Coordination
- Schedule a kickoff meeting to align owners, share the plan, and agree on tooling for tracking progress.
- Establish a shared tracking board (Jira/Linear) using the tasks above as initial tickets.
- Define checkpoints after each phase to validate readiness before moving into implementation.

## Assumptions & Risks
- Assumes no additional hardware integrations unique to iPad exist; if discovered during Phase 1, include mitigation plans.
- Relies on access to design tooling and existing CI credentials.
- Any Firebase or StoreKit configuration changes uncovered must be coordinated with backend teams before implementation.

