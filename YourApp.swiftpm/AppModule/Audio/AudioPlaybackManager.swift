import AVFoundation
import Foundation

/// §3.15 — plays pronunciation clips by streaming `pronunciation_audio_url`
/// directly, no local caching (clips are expected to be short, <2s, so a
/// re-stream on replay is acceptable). Uses `AVPlayer` rather than the
/// plan's literal "AVAudioPlayer": `AVAudioPlayer` only plays local file
/// data, not a remote stream, so it can't actually do what the plan
/// describes ("streaming the URL directly"); `AVPlayer` is the API that
/// matches that intent.
@MainActor
final class AudioPlaybackManager {
    static let shared = AudioPlaybackManager()

    private var player: AVPlayer?

    private init() {}

    func play(url: URL) {
        let item = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: item)
        player = newPlayer
        newPlayer.play()
    }
}
