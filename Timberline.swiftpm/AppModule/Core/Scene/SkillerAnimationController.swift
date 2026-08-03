import RealityKit
import SwiftUI

/// A lightweight animation controller for the bundled Skiller USDZ assets.
/// It keeps the public API from the issue notes while falling back gracefully
/// if any of the animation variants are unavailable in the current build.
@MainActor
final class SkillerAnimationController {
    enum State: Equatable {
        case idle
        case walking
        case running
        case chopping
    }

    private let rootEntity: Entity
    private let idleResource: AnimationResource?
    private let walkResource: AnimationResource?
    private let runResource: AnimationResource?
    private let chopResource: AnimationResource?

    private var currentState: State = .idle
    private var previousMovementState: State = .idle
    private var activeChopTask: Task<Void, Never>?

    init(rootEntity: Entity) {
        self.rootEntity = rootEntity
        self.idleResource = Self.loadAnimation(named: "Skiller_Idle")
        self.walkResource = Self.loadAnimation(named: "Skiller_Walk")
        self.runResource = Self.loadAnimation(named: "Skiller_Run")
        self.chopResource = Self.loadAnimation(named: "Skiller_Chop")

        applyState(.idle)
    }

    func setMovement(isMoving: Bool, isRunning: Bool) {
        let nextState: State = isMoving ? (isRunning ? .running : .walking) : .idle
        guard nextState != currentState else { return }
        previousMovementState = nextState
        applyState(nextState)
    }

    func playChop() {
        guard currentState != .chopping else { return }
        activeChopTask?.cancel()
        previousMovementState = currentState == .chopping ? previousMovementState : currentState
        applyState(.chopping)

        activeChopTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            self.applyState(self.previousMovementState)
        }
    }

    private func applyState(_ state: State) {
        currentState = state

        switch state {
        case .idle:
            if let resource = idleResource {
                rootEntity.playAnimation(resource, transitionDuration: 0.2)
            }
        case .walking:
            if let resource = walkResource {
                rootEntity.playAnimation(resource, transitionDuration: 0.2)
            }
        case .running:
            if let resource = runResource {
                rootEntity.playAnimation(resource, transitionDuration: 0.2)
            }
        case .chopping:
            if let resource = chopResource {
                rootEntity.playAnimation(resource, transitionDuration: 0.12)
            }
        }
    }

    private static func loadAnimation(named assetName: String) -> AnimationResource? {
        guard let entity = try? Entity.loadModel(named: assetName) else { return nil }
        return entity.availableAnimations.first
    }
}
