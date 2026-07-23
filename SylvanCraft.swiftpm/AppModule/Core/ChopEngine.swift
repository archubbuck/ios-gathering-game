import Combine
import Foundation

/// Drives `GameState.performChopTick()` on a fixed interval while a chop
/// is active. The timer only exists mid-chop — idle screens run no timer
/// at all (battery).
@MainActor
final class ChopEngine: ObservableObject {
    private var tickSub: AnyCancellable?
    private var chopObservation: AnyCancellable?

    func attach(to game: GameState) {
        guard chopObservation == nil else { return }
        chopObservation = game.$activeChopTreeID
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self, weak game] chopping in
                guard let self else { return }
                if chopping {
                    self.tickSub = Timer.publish(
                        every: GameData.tickInterval, on: .main, in: .common
                    )
                    .autoconnect()
                    .sink { [weak game] _ in
                        game?.performChopTick()
                    }
                } else {
                    self.tickSub = nil
                }
            }
    }
}
