import AVFoundation
import Foundation
import UIKit

/// Haptics.
///
/// Half the tactility of this game is in the taptic engine rather than on
/// screen: a PERFECT and a GOOD look similar in peripheral vision and feel
/// completely different in the hand, which is what teaches the rhythm.
///
/// Generators are prepared once and kept, because preparing one lazily inside a
/// tap adds enough latency to break the timing feel it exists to convey.
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let notice = UINotificationFeedbackGenerator()

    static func prepare() {
        [light, medium, heavy, rigid].forEach { $0.prepare() }
        notice.prepare()
    }

    static func tap(_ tier: ComboTier) {
        switch tier {
        case .miss: light.impactOccurred(intensity: 0.4)
        case .good: light.impactOccurred()
        case .great: medium.impactOccurred()
        case .perfect: heavy.impactOccurred()
        case .tremendous:
            heavy.impactOccurred(intensity: 1.0)
            // A double tick, so the top tier is unmistakable without looking.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                rigid.impactOccurred(intensity: 0.9)
            }
        }
    }

    static func pop() { rigid.impactOccurred(intensity: 0.75) }
    static func inflate() { light.impactOccurred(intensity: 0.55) }
    static func bounce() { medium.impactOccurred(intensity: 0.7) }
    static func launch() { notice.notificationOccurred(.success) }
}

/// Sound, synthesised rather than sampled.
///
/// There are no audio files in this project. Every cue is a short generated
/// tone, which keeps the bundle to almost nothing, means no licensing question
/// about any asset, and lets the pitch of a combo hit rise with the tier so the
/// rhythm is audible as well as visible.
final class Audio {
    static let shared = Audio()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var format: AVAudioFormat?
    private var isRunning = false

    /// Off by default is wrong for a game like this, but a game that seizes the
    /// audio session from whatever the player is listening to is worse. Ambient
    /// means the music keeps playing and these cues sit on top.
    private init() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let fmt = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        format = fmt
        engine.attach(player)
        if let fmt { engine.connect(player, to: engine.mainMixerNode, format: fmt) }
        engine.mainMixerNode.outputVolume = 0.6
    }

    private func start() {
        guard !isRunning else { return }
        do {
            try engine.start()
            player.play()
            isRunning = true
        } catch {
            isRunning = false
        }
    }

    /// One short tone with a percussive envelope.
    private func tone(frequency: Double, seconds: Double, volume: Double, wobble: Double = 0) {
        guard let format else { return }
        start()
        guard isRunning else { return }

        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0]
        else { return }
        buffer.frameLength = frames

        for i in 0..<Int(frames) {
            let t = Double(i) / format.sampleRate
            let progress = t / seconds
            // Fast attack, exponential decay. A tone without an envelope is a
            // beep; with one it is a hit.
            let envelope = exp(-progress * 9) * min(progress * 60, 1)
            let vibrato = wobble > 0 ? sin(t * .pi * 2 * 7) * wobble : 0
            let sample = sin(t * .pi * 2 * (frequency + vibrato * frequency))
            channel[i] = Float(sample * envelope * volume)
        }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }

    /// The shove. Pitch rises with the tier, which is the audible half of the
    /// rhythm.
    func thump(tier: ComboTier) {
        let pitch: Double
        switch tier {
        case .miss: pitch = 110
        case .good: pitch = 196
        case .great: pitch = 262
        case .perfect: pitch = 330
        case .tremendous: pitch = 440
        }
        tone(frequency: pitch, seconds: 0.16, volume: 0.5)
        if tier == .tremendous {
            tone(frequency: pitch * 1.5, seconds: 0.22, volume: 0.32)
        }
    }

    func pop() { tone(frequency: 720, seconds: 0.1, volume: 0.45) }
    func inflate() { tone(frequency: 150, seconds: 0.26, volume: 0.38, wobble: 0.04) }
    func quote() { tone(frequency: 520, seconds: 0.07, volume: 0.18) }
    func splash() { tone(frequency: 240, seconds: 0.18, volume: 0.3, wobble: 0.08) }
    func phase() { tone(frequency: 392, seconds: 0.3, volume: 0.4) }

    func launch() {
        // A rising run, which is the only place in the game with a melody.
        let notes: [Double] = [262, 330, 392, 523, 659]
        for (i, note) in notes.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.08) { [weak self] in
                self?.tone(frequency: note, seconds: 0.28, volume: 0.45)
            }
        }
    }
}

/// The two numbers worth keeping between launches.
///
/// UserDefaults, which is a Required Reason API: the privacy manifest declares
/// CA92.1 for it. Nothing else is stored, and nothing leaves the device.
enum Scores {
    private static let bestLaunchKey = "best.launch.metres"
    private static let bestTimeKey = "best.clear.seconds"

    static var bestLaunch: Double {
        get { UserDefaults.standard.double(forKey: bestLaunchKey) }
        set { UserDefaults.standard.set(newValue, forKey: bestLaunchKey) }
    }

    /// Zero means "never cleared", so the title screen can stay quiet.
    static var bestClear: Double {
        get { UserDefaults.standard.double(forKey: bestTimeKey) }
        set { UserDefaults.standard.set(newValue, forKey: bestTimeKey) }
    }

    /// Fold in a finished round. Returns whether anything was a personal best.
    @discardableResult
    static func record(_ result: RoundResult) -> Bool {
        var improved = false
        if result.launchMetres > bestLaunch {
            bestLaunch = result.launchMetres
            improved = true
        }
        if bestClear == 0 || result.clearSeconds < bestClear {
            bestClear = result.clearSeconds
            improved = true
        }
        return improved
    }
}
