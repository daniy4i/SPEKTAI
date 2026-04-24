//
//  TaskService.swift
//  lannaapp
//
//  CRUD service for SpektTask. All network calls are async/await.
//  Optimistic updates keep the UI responsive — errors are silent (state already correct).
//

import SwiftUI

// MARK: - Notification

extension Notification.Name {
    static let spektTasksUpdated = Notification.Name("spektTasksUpdated")
}

// MARK: - Service

@MainActor
final class TaskService: ObservableObject {

    static let shared = TaskService()
    private init() {}

    // MARK: Published

    @Published var tasks    : [SpektTask] = SpektTask.mocks   // preloaded with demo data
    @Published var loadState: LoadState  = .idle

    // MARK: Config

    private let baseURL = SpektConfig.apiBase

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }()

    // MARK: - Computed

    var pendingTasks   : [SpektTask] { tasks.filter { $0.status == .pending } }
    var completedTasks : [SpektTask] { tasks.filter { $0.status == .completed } }
    var overdueCount   : Int         { tasks.filter { $0.isOverdue }.count }
    var todayCount     : Int         { tasks.filter { $0.isDueToday && $0.status == .pending }.count }

    var groupedSections: [TaskSection] { tasks.grouped() }

    // MARK: - Load

    func loadTasks() async {
        guard loadState != .loading else { return }
        loadState = .loading
        do {
            let fetched: [SpektTask] = try await get(path: "/tasks")
            withAnimation(SpektTheme.Motion.springDefault) {
                tasks     = fetched
                loadState = .loaded
            }
        } catch {
            loadState = .failed(error.localizedDescription)
            // Keep demo data visible
        }
    }

    // MARK: - Create

    func addTask(title: String, detail: String? = nil,
                 deadline: String? = nil, priority: TaskPriority = .medium) async {
        // Optimistic insert
        let local = SpektTask(
            id:          UUID().uuidString,
            title:       title,
            detail:      detail,
            deadline:    deadline,
            status:      .pending,
            priority:    priority,
            sourceSessionId: nil,
            createdAt:   ISO8601DateFormatter().string(from: Date())
        )
        withAnimation(SpektTheme.Motion.springDefault) {
            tasks.insert(local, at: 0)
        }

        // Sync to backend
        struct Body: Encodable {
            let title: String; let detail: String?
            let deadline: String?; let priority: String
        }
        if let confirmed: SpektTask = try? await post(
            path: "/tasks",
            body: Body(title: title, detail: detail, deadline: deadline, priority: priority.rawValue)
        ) {
            // Replace optimistic entry with server-confirmed one
            if let idx = tasks.firstIndex(where: { $0.id == local.id }) {
                tasks[idx] = confirmed
            }
        }
    }

    /// Import tasks extracted from a call session. Deduplicates by sourceSessionId.
    func importTasks(_ extracted: [ExtractedTask], sessionId: String) async {
        guard !extracted.isEmpty else { return }

        // Don't import if we already have tasks from this session
        guard !tasks.contains(where: { $0.sourceSessionId == sessionId }) else { return }

        let newTasks: [SpektTask] = extracted.map { et in
            SpektTask(
                id:          et.id,
                title:       et.title,
                detail:      et.detail,
                deadline:    et.dueDate,
                status:      .pending,
                priority:    TaskPriority(rawValue: et.priority) ?? .medium,
                sourceSessionId: sessionId,
                createdAt:   ISO8601DateFormatter().string(from: Date())
            )
        }

        withAnimation(SpektTheme.Motion.springDefault) {
            tasks.insert(contentsOf: newTasks, at: 0)
        }

        // Batch sync to backend
        struct BatchBody: Encodable {
            let tasks: [TaskBody]; let sourceSessionId: String
            struct TaskBody: Encodable {
                let id, title: String; let detail, deadline: String?; let priority: String
            }
        }
        let body = BatchBody(
            tasks: newTasks.map {
                .init(id: $0.id, title: $0.title, detail: $0.detail,
                      deadline: $0.deadline, priority: $0.priority.rawValue)
            },
            sourceSessionId: sessionId
        )
        let _: [SpektTask]? = try? await post(path: "/tasks/batch", body: body)

        NotificationCenter.default.post(name: .spektTasksUpdated, object: nil)
    }

    // MARK: - Update

    func update(_ task: SpektTask) async {
        guard let idx = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(SpektTheme.Motion.springDefault) { tasks[idx] = task }

        struct Patch: Encodable {
            let title: String; let detail: String?
            let deadline: String?; let priority: String; let status: String
        }
        let _: SpektTask? = try? await patch(
            path: "/tasks/\(task.id)",
            body: Patch(title: task.title, detail: task.detail,
                        deadline: task.deadline, priority: task.priority.rawValue,
                        status: task.status.rawValue)
        )
    }

    // MARK: - Complete / Reopen

    func toggleComplete(id: String) {
        guard let idx = tasks.firstIndex(where: { $0.id == id }) else { return }
        let newStatus: TaskStatus = tasks[idx].status == .completed ? .pending : .completed
        var updated = tasks[idx]
        updated.status = newStatus
        withAnimation(SpektTheme.Motion.springBouncy) { tasks[idx] = updated }
        #if os(iOS)
        HapticEngine.impact(newStatus == .completed ? .medium : .light)
        #endif
        Task { await update(updated) }
    }

    // MARK: - Delete

    func delete(id: String) {
        withAnimation(SpektTheme.Motion.springDefault) {
            tasks.removeAll { $0.id == id }
        }
        Task {
            var req = URLRequest(url: URL(string: "\(baseURL)/tasks/\(id)")!)
            req.httpMethod = "DELETE"
            try? await URLSession.shared.data(for: req)
        }
    }

    // MARK: - Networking

    private func get<T: Decodable>(path: String) async throws -> T {
        let url = URL(string: "\(baseURL)\(path)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try decoder.decode(T.self, from: data)
    }

    private func post<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        var req = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(T.self, from: data)
    }

    private func patch<B: Encodable, T: Decodable>(path: String, body: B) async throws -> T {
        var req = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        req.httpMethod = "PATCH"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        let (data, _) = try await URLSession.shared.data(for: req)
        return try decoder.decode(T.self, from: data)
    }
}
