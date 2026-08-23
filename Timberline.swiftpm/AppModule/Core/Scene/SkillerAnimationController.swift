import Foundation

/// Tracks the player character's 2D animation state. In the 2D renderer
/// there are no USDZ skeletal animations — this lightweight controller
/// simply records the current state so `ForestSceneView.Coordinator` can
/// drive sprite-level feedback (e.g. the chop-shake action).
final class SkillerAnimationController {
    enum State: Equatable {
        case idle
        case walking
        case chopping
    }

    private(set) var currentState: State = .idle
    private var activeChopTask: Task<Void, Never>?

    func setMovement(isMoving: Bool) {
        guard currentState != .chopping else { return }
        currentState = isMoving ? .walking : .idle
    }

    func playChop() {
        activeChopTask?.cancel()
        currentState = .chopping
        activeChopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, let self else { return }
            self.currentState = .idle
        }
    }
}
