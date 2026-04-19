//
//  TasksView.swift
//  lannaapp
//
//  Full task management screen — presented as a sheet from ActivityView.
//  Shows all tasks grouped by urgency with interactive cards.
//
//  Interactions:
//    Tap circle    → toggle complete (spring animation)
//    Tap row       → edit sheet
//    Swipe left    → delete
//    "+" button    → add task sheet
//

import SwiftUI

// MARK: - Animated Checkbox
// Internal (not private) so ActivityView.CompactTaskCard can reference it.

struct TaskCheckbox: View {
    let isCompleted : Bool
    let priority    : TaskPriority
    let onToggle    : () -> Void

    @State private var scale: CGFloat = 1.0

    var body: some View {
        Button {
            withAnimation(SpektTheme.Motion.springBouncy) { scale = 0.72 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(SpektTheme.Motion.springBouncy) { scale = 1.0 }
                onToggle()
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        isCompleted ? SpektTheme.Colors.positive : priority.color.opacity(0.55),
                        lineWidth: isCompleted ? 0 : 1.5
                    )
                    .background(
                        Circle()
                            .fill(isCompleted ? SpektTheme.Colors.positive : Color.clear)
                    )
                    .frame(width: 22, height: 22)

                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .transition(.scale(scale: 0.4).combined(with: .opacity))
                }
            }
            .animation(SpektTheme.Motion.springBouncy, value: isCompleted)
        }
        .buttonStyle(.plain)
        .scaleEffect(scale)
    }
}

// MARK: - Deadline Badge

private struct DeadlineBadge: View {
    let text : String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background {
                Capsule()
                    .fill(color.opacity(0.12))
                    .overlay(Capsule().strokeBorder(color.opacity(0.25), lineWidth: 0.5))
            }
    }
}

// MARK: - Task Row

private struct TaskRow: View {
    let task    : SpektTask
    let onToggle: () -> Void
    let onEdit  : () -> Void
    let onDelete: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 12) {
            TaskCheckbox(
                isCompleted: task.isCompleted,
                priority: task.priority,
                onToggle: onToggle
            )

            // Content
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(SpektTheme.Typography.bodySmall)
                    .foregroundColor(
                        task.isCompleted
                            ? SpektTheme.Colors.textTertiary
                            : SpektTheme.Colors.textPrimary
                    )
                    .strikethrough(task.isCompleted, color: SpektTheme.Colors.textTertiary)
                    .lineLimit(2)
                    .animation(SpektTheme.Motion.springDefault, value: task.isCompleted)

                if let detail = task.detail, !detail.isEmpty, !task.isCompleted {
                    Text(detail)
                        .font(SpektTheme.Typography.caption)
                        .foregroundColor(SpektTheme.Colors.textTertiary)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            Spacer(minLength: 0)

            // Right side: deadline + priority icon
            HStack(spacing: 6) {
                if let label = task.deadlineDisplay {
                    DeadlineBadge(text: label, color: task.deadlineColor)
                }

                if !task.isCompleted {
                    Image(systemName: task.priority.icon)
                        .font(.system(size: 12))
                        .foregroundColor(task.priority.color.opacity(0.65))
                }
            }

            // Edit chevron
            if !task.isCompleted {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.45))
            }
        }
        .padding(.horizontal, SpektTheme.Spacing.md)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { if !task.isCompleted { onEdit() } }
        // Swipe to delete
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete() } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button { onToggle() } label: {
                Label(task.isCompleted ? "Reopen" : "Done",
                      systemImage: task.isCompleted ? "arrow.counterclockwise" : "checkmark")
            }
            .tint(SpektTheme.Colors.positive)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault) { appeared = true }
        }
    }
}

// MARK: - Task Section Header

private struct TaskSectionHeader: View {
    let section: TaskSection

    var body: some View {
        HStack(spacing: 7) {
            Text(section.title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(section.color)

            Text("\(section.tasks.count)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(section.color.opacity(0.70))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule().fill(section.color.opacity(0.12))
                }
        }
        .padding(.horizontal, SpektTheme.Spacing.xl)
        .padding(.top, 22)
        .padding(.bottom, 8)
    }
}

// MARK: - Task Edit Sheet

struct TaskEditSheet: View {
    @Binding var task: SpektTask
    let onSave  : (SpektTask) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var titleFocused: Bool

    @State private var editTitle    : String
    @State private var editDetail   : String
    @State private var editDeadline : Date?
    @State private var editPriority : TaskPriority
    @State private var showDatePicker = false
    @State private var appeared       = false

    init(task: Binding<SpektTask>, onSave: @escaping (SpektTask) -> Void, onDelete: @escaping () -> Void) {
        self._task       = task
        self.onSave      = onSave
        self.onDelete    = onDelete
        _editTitle       = State(initialValue: task.wrappedValue.title)
        _editDetail      = State(initialValue: task.wrappedValue.detail ?? "")
        _editDeadline    = State(initialValue: task.wrappedValue.deadlineDate)
        _editPriority    = State(initialValue: task.wrappedValue.priority)
    }

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: SpektTheme.Spacing.lg) {

                        // ── Title ─────────────────────────────────────────
                        VStack(alignment: .leading, spacing: 6) {
                            Text("TASK")
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(2.0)
                                .foregroundColor(SpektTheme.Colors.textTertiary)

                            TextField("Task title", text: $editTitle, axis: .vertical)
                                .font(.system(size: 22, weight: .light))
                                .foregroundColor(SpektTheme.Colors.textPrimary)
                                .tint(SpektTheme.Colors.accent)
                                .focused($titleFocused)
                                .lineLimit(3)
                        }
                        .padding(.horizontal, SpektTheme.Spacing.xl)

                        // ── Detail ────────────────────────────────────────
                        GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.md) {
                            VStack(alignment: .leading, spacing: 0) {
                                Label("Detail", systemImage: "text.alignleft")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.6)
                                    .foregroundColor(SpektTheme.Colors.textTertiary)
                                    .padding(.horizontal, SpektTheme.Spacing.md)
                                    .padding(.top, SpektTheme.Spacing.md)
                                    .padding(.bottom, 8)

                                GlassDivider(opacity: 0.06)

                                ZStack(alignment: .topLeading) {
                                    if editDetail.isEmpty {
                                        Text("Optional context…")
                                            .font(SpektTheme.Typography.bodySmall)
                                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.45))
                                            .padding(.top, 10)
                                            .padding(.leading, 14)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $editDetail)
                                        .font(SpektTheme.Typography.bodySmall)
                                        .foregroundColor(SpektTheme.Colors.textSecondary)
                                        .scrollContentBackground(.hidden)
                                        .frame(height: 64)
                                        .padding(.horizontal, 10)
                                }
                            }
                        }
                        .padding(.horizontal, SpektTheme.Spacing.xl)

                        // ── Priority ──────────────────────────────────────
                        GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.md) {
                            VStack(alignment: .leading, spacing: 0) {
                                Label("Priority", systemImage: "flag")
                                    .font(.system(size: 10, weight: .semibold))
                                    .tracking(1.6)
                                    .foregroundColor(SpektTheme.Colors.textTertiary)
                                    .padding(.horizontal, SpektTheme.Spacing.md)
                                    .padding(.top, SpektTheme.Spacing.md)
                                    .padding(.bottom, 10)

                                GlassDivider(opacity: 0.06)

                                HStack(spacing: SpektTheme.Spacing.sm) {
                                    ForEach(TaskPriority.allCases, id: \.self) { p in
                                        let selected = editPriority == p
                                        Button {
                                            #if os(iOS)
                                            HapticEngine.impact(.light)
                                            #endif
                                            withAnimation(SpektTheme.Motion.springSnappy) { editPriority = p }
                                        } label: {
                                            HStack(spacing: 5) {
                                                Circle()
                                                    .fill(p.color)
                                                    .frame(width: 6, height: 6)
                                                Text(p.label)
                                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                            }
                                            .foregroundColor(selected ? .white : SpektTheme.Colors.textSecondary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background {
                                                RoundedRectangle(cornerRadius: SpektTheme.Radius.sm, style: .continuous)
                                                    .fill(selected ? p.color : Color.white.opacity(0.04))
                                                    .overlay {
                                                        RoundedRectangle(cornerRadius: SpektTheme.Radius.sm, style: .continuous)
                                                            .strokeBorder(
                                                                selected ? p.color.opacity(0.4) : Color.white.opacity(0.07),
                                                                lineWidth: 0.5
                                                            )
                                                    }
                                            }
                                        }
                                        .buttonStyle(PressableButtonStyle(scale: 0.95))
                                    }
                                }
                                .padding(.horizontal, SpektTheme.Spacing.md)
                                .padding(.bottom, SpektTheme.Spacing.md)
                            }
                        }
                        .padding(.horizontal, SpektTheme.Spacing.xl)

                        // ── Deadline ──────────────────────────────────────
                        GlassCard(intensity: .thin, cornerRadius: SpektTheme.Radius.md) {
                            VStack(spacing: 0) {
                                Button {
                                    #if os(iOS)
                                    HapticEngine.selection()
                                    #endif
                                    withAnimation(SpektTheme.Motion.springDefault) {
                                        showDatePicker.toggle()
                                        if showDatePicker && editDeadline == nil {
                                            editDeadline = Calendar.current.date(byAdding: .day, value: 1, to: Date())
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Label("Deadline", systemImage: "calendar")
                                            .font(.system(size: 10, weight: .semibold))
                                            .tracking(1.6)
                                            .foregroundColor(SpektTheme.Colors.textTertiary)
                                        Spacer()
                                        if let d = editDeadline {
                                            Text(DateFormatter.taskDisplay.string(from: d))
                                                .font(SpektTheme.Typography.bodySmall.weight(.medium))
                                                .foregroundColor(SpektTheme.Colors.accent)
                                            Button {
                                                withAnimation(SpektTheme.Motion.springSnappy) { editDeadline = nil; showDatePicker = false }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(SpektTheme.Colors.textTertiary)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            Text("Set deadline")
                                                .font(SpektTheme.Typography.bodySmall)
                                                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.55))
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.45))
                                            .rotationEffect(.degrees(showDatePicker ? 90 : 0))
                                            .animation(SpektTheme.Motion.springSnappy, value: showDatePicker)
                                    }
                                    .padding(SpektTheme.Spacing.md)
                                }
                                .buttonStyle(.plain)

                                if showDatePicker {
                                    GlassDivider(opacity: 0.06)
                                    DatePicker(
                                        "",
                                        selection: Binding(
                                            get: { editDeadline ?? Date() },
                                            set: { editDeadline = $0 }
                                        ),
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    .tint(SpektTheme.Colors.accent)
                                    .padding(.horizontal, SpektTheme.Spacing.sm)
                                    .transition(.cardBodyReveal)
                                }
                            }
                        }
                        .padding(.horizontal, SpektTheme.Spacing.xl)

                        Spacer(minLength: SpektTheme.Spacing.xxl)
                    }
                }

                // ── Actions ───────────────────────────────────────────────
                VStack(spacing: 10) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Text("Save")
                            .font(SpektTheme.Typography.titleSmall)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background {
                                Capsule()
                                    .fill(SpektTheme.Colors.accent)
                                    .overlay {
                                        Capsule().fill(LinearGradient(
                                            colors: [Color.white.opacity(0.16), Color.clear],
                                            startPoint: .top, endPoint: .center
                                        ))
                                    }
                                    .shadow(color: SpektTheme.Colors.accent.opacity(0.40), radius: 16, x: 0, y: 5)
                            }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.97))
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("Delete Task")
                            .font(SpektTheme.Typography.bodySmall)
                            .foregroundColor(SpektTheme.Colors.destructive.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.97))
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .padding(.bottom, SpektTheme.Spacing.xl)
                .opacity(appeared ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.05)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { titleFocused = true }
        }
    }

    private func saveAndDismiss() {
        var updated = task
        updated.title    = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.detail   = editDetail.isEmpty ? nil : editDetail
        updated.priority = editPriority
        if let d = editDeadline {
            updated.deadline = ISO8601DateFormatter.dateOnly.string(from: d)
        } else {
            updated.deadline = nil
        }
        #if os(iOS)
        HapticEngine.impact(.light)
        #endif
        onSave(updated)
        dismiss()
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title    = ""
    @State private var deadline : Date? = nil
    @State private var priority : TaskPriority = .medium
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .padding(.top, 14)
                    .padding(.bottom, 28)

                // Icon
                ZStack {
                    Circle()
                        .fill(SpektTheme.Colors.accent.opacity(0.10))
                        .frame(width: 56, height: 56)
                        .overlay(Circle().strokeBorder(SpektTheme.Colors.accent.opacity(0.18), lineWidth: 0.5))
                    Image(systemName: "plus.circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundColor(SpektTheme.Colors.accent)
                }
                .padding(.bottom, 18)

                Text("New Task")
                    .font(SpektTheme.Typography.titleLarge)
                    .foregroundColor(SpektTheme.Colors.textPrimary)
                    .padding(.bottom, 28)

                // Title input
                ZStack(alignment: .leading) {
                    if title.isEmpty {
                        Text("What needs to be done?")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.50))
                            .allowsHitTesting(false)
                    }
                    TextField("", text: $title)
                        .font(.system(size: 18, weight: .light))
                        .foregroundColor(SpektTheme.Colors.textPrimary)
                        .tint(SpektTheme.Colors.accent)
                        .focused($focused)
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .padding(.bottom, 20)

                GlassDivider(opacity: 0.08)
                    .padding(.horizontal, SpektTheme.Spacing.xl)
                    .padding(.bottom, 20)

                // Priority quick-select
                HStack(spacing: SpektTheme.Spacing.sm) {
                    ForEach(TaskPriority.allCases, id: \.self) { p in
                        Button {
                            withAnimation(SpektTheme.Motion.springSnappy) { priority = p }
                            #if os(iOS)
                            HapticEngine.impact(.light)
                            #endif
                        } label: {
                            HStack(spacing: 4) {
                                Circle().fill(p.color).frame(width: 5, height: 5)
                                Text(p.label)
                                    .font(SpektTheme.Typography.caption)
                                    .fontWeight(priority == p ? .semibold : .regular)
                            }
                            .foregroundColor(priority == p ? .white : SpektTheme.Colors.textSecondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background {
                                Capsule()
                                    .fill(priority == p ? p.color : Color.white.opacity(0.05))
                                    .overlay(Capsule().strokeBorder(
                                        priority == p ? p.color.opacity(0.3) : Color.white.opacity(0.08),
                                        lineWidth: 0.5
                                    ))
                            }
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.94))
                    }
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        Task { await TaskService.shared.addTask(title: t, priority: priority) }
                        #if os(iOS)
                        HapticEngine.impact(.medium)
                        #endif
                        dismiss()
                    } label: {
                        Text("Add Task")
                            .font(SpektTheme.Typography.titleSmall)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background {
                                Capsule()
                                    .fill(SpektTheme.Colors.accent)
                                    .shadow(color: SpektTheme.Colors.accent.opacity(0.40), radius: 14, x: 0, y: 5)
                            }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.97))
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    Button { dismiss() } label: {
                        Text("Cancel")
                            .font(SpektTheme.Typography.bodyMedium)
                            .foregroundColor(SpektTheme.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.98))
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .padding(.bottom, SpektTheme.Spacing.xl)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { focused = true }
        }
    }
}

// MARK: - Tasks View

struct TasksView: View {
    @ObservedObject private var service = TaskService.shared
    @Environment(\.dismiss) private var dismiss

    @State private var editingTask  : SpektTask? = nil
    @State private var showAddSheet = false
    @State private var appeared     = false

    var body: some View {
        ZStack {
            SpektTheme.Colors.base.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ─────────────────────────────────────────────────
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TASKS")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2.8)
                            .foregroundColor(SpektTheme.Colors.textTertiary)
                        Text("\(service.pendingTasks.count) pending")
                            .font(SpektTheme.Typography.displayMedium)
                            .foregroundColor(SpektTheme.Colors.textPrimary)
                    }

                    Spacer()

                    // Add button
                    Button {
                        #if os(iOS)
                        HapticEngine.selection()
                        #endif
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background {
                                Circle()
                                    .fill(SpektTheme.Colors.accent)
                                    .shadow(color: SpektTheme.Colors.accent.opacity(0.40), radius: 10, x: 0, y: 4)
                            }
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.88))
                }
                .padding(.horizontal, SpektTheme.Spacing.xl)
                .padding(.top, 28)
                .padding(.bottom, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : -8)

                GlassDivider(opacity: 0.07)

                // ── Task List ──────────────────────────────────────────────
                if service.tasks.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(service.groupedSections) { section in
                            Section {
                                ForEach(section.tasks) { task in
                                    TaskRow(
                                        task:     task,
                                        onToggle: { service.toggleComplete(id: task.id) },
                                        onEdit:   {
                                            editingTask = task
                                            #if os(iOS)
                                            HapticEngine.selection()
                                            #endif
                                        },
                                        onDelete: { service.delete(id: task.id) }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets())
                                    .listRowSeparator(.hidden)
                                }
                            } header: {
                                TaskSectionHeader(section: section)
                                    .listRowInsets(EdgeInsets())
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .onAppear {
            withAnimation(SpektTheme.Motion.springDefault.delay(0.04)) { appeared = true }
        }
        // Edit sheet
        .sheet(item: $editingTask) { task in
            if let idx = service.tasks.firstIndex(where: { $0.id == task.id }) {
                TaskEditSheet(
                    task:     $service.tasks[idx],
                    onSave:   { updated in Task { await service.update(updated) } },
                    onDelete: { service.delete(id: task.id) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
            }
        }
        // Add sheet
        .sheet(isPresented: $showAddSheet) {
            AddTaskSheet()
                .presentationDetents([.height(400)])
                .presentationDragIndicator(.hidden)
                .presentationBackground(SpektTheme.Colors.base)
                .presentationCornerRadius(SpektTheme.Radius.xl)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 40, weight: .ultraLight))
                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.35))
            Text("No tasks yet")
                .font(SpektTheme.Typography.bodyMedium)
                .foregroundColor(SpektTheme.Colors.textTertiary)
            Text("Tasks from your calls appear here automatically.")
                .font(SpektTheme.Typography.bodySmall)
                .foregroundColor(SpektTheme.Colors.textTertiary.opacity(0.60))
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpektTheme.Spacing.xxl)

            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Add a task")
                        .font(SpektTheme.Typography.bodySmall.weight(.medium))
                }
                .foregroundColor(SpektTheme.Colors.accent)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background {
                    Capsule()
                        .fill(SpektTheme.Colors.accent.opacity(0.10))
                        .overlay(Capsule().strokeBorder(SpektTheme.Colors.accent.opacity(0.25), lineWidth: 0.5))
                }
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - DateFormatter Helper

private extension DateFormatter {
    static let taskDisplay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
}

// MARK: - Preview

#Preview {
    TasksView()
        .preferredColorScheme(.dark)
}
