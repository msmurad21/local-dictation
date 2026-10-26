import AppKit

@MainActor final class RecordingSounds {
    enum Cue: String { case start, stop }
    private var playing: NSSound?

    func play(_ cue: Cue) {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Sounds/\(cue.rawValue).wav"),
              let sound = NSSound(contentsOf: url, byReference: false) else { return }
        playing?.stop()
        sound.volume = 0.3
        playing = sound
        sound.play()
    }
}
