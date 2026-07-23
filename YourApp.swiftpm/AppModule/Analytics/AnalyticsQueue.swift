import Foundation

/// §3.19 — client-side event queue: buffered in memory, mirrored to
/// UserDefaults so events aren't lost if the app is terminated before they
/// flush. Flushes on whichever comes first: 20 queued events, a 30s timer,
/// or the app backgrounding (driven from `scenePhase` at the call site,
/// not tracked here). `POST /analytics/events` is fire-and-forget from the
/// client's perspective — one immediate retry on failure, then the batch
/// is dropped; this isn't mission-critical data.
@MainActor
final class AnalyticsQueue {
    static let shared = AnalyticsQueue()

    private let flushThreshold = 20
    private let flushInterval: TimeInterval = 30
    private static let persistenceKey = "pendingAnalyticsEvents"

    private var pending: [AnalyticsEventPayload]
    private var flushTimer: Timer?

    private init() {
        pending = Self.loadPersisted()
        flushTimer = Timer.scheduledTimer(withTimeInterval: flushInterval, repeats: true) { _ in
            Task { @MainActor in AnalyticsQueue.shared.flush() }
        }
    }

    func record(eventType: String, payload: [String: String] = [:]) {
        pending.append(
            AnalyticsEventPayload(eventType: eventType, payload: payload, occurredAt: Date())
        )
        persist()
        if pending.count >= flushThreshold {
            flush()
        }
    }

    /// Safe to call anytime, including with an empty queue (no-ops).
    func flush() {
        guard !pending.isEmpty else { return }
        let batch = pending
        pending.removeAll()
        persist()

        Task {
            do {
                try await APIClient.shared.sendAnalyticsEvents(batch)
            } catch {
                // One immediate retry (§3.19), then accept the loss.
                try? await APIClient.shared.sendAnalyticsEvents(batch)
            }
        }
    }

    private func persist() {
        let data = try? JSONEncoder().encode(pending)
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    private static func loadPersisted() -> [AnalyticsEventPayload] {
        guard
            let data = UserDefaults.standard.data(forKey: persistenceKey),
            let decoded = try? JSONDecoder().decode([AnalyticsEventPayload].self, from: data)
        else {
            return []
        }
        return decoded
    }
}
