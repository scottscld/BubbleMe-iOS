import AVFoundation
import Foundation

/// Procedural music + SFX (same idea as bubbleme.fun). No audio files required.
final class AudioEngine {
    static let shared = AudioEngine()
    private let engine = AVAudioEngine()
    private let sfx = AVAudioMixerNode()
    private let music = AVAudioMixerNode()
    private var started = false
    private var musicTimer: Timer?
    private var step = 0
    var musicOn = true { didSet { music.outputVolume = musicOn ? 0.18 : 0 } }
    var sfxOn = true

    func start() {
        guard !started else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        engine.attach(sfx)
        engine.attach(music)
        engine.connect(sfx, to: engine.mainMixerNode, format: nil)
        engine.connect(music, to: engine.mainMixerNode, format: nil)
        sfx.outputVolume = 1
        music.outputVolume = musicOn ? 0.18 : 0
        try? engine.start()
        started = true
        startMusic()
    }

    func stopMusic() {
        musicTimer?.invalidate()
        musicTimer = nil
    }

    private func startMusic() {
        stopMusic()
        let notes: [Float] = [261.6, 329.6, 392.0, 493.9, 523.3, 493.9, 392.0, 329.6]
        let t = Timer(timeInterval: 0.42, repeats: true) { [weak self] _ in
            guard let self, self.musicOn, self.started else { return }
            let f = notes[self.step % notes.count]
            self.step += 1
            self.tone(f, dur: 0.28, volume: 0.05, to: self.music)
        }
        RunLoop.main.add(t, forMode: .common)
        musicTimer = t
    }

    func shoot() { beep(880, 0.06, 0.12) }
    func pop() { beep(620, 0.08, 0.14, slide: 1.4) }
    func drop() { beep(180, 0.16, 0.12, slide: 0.5) }
    func bomb() { beep(90, 0.22, 0.2, slide: 0.4) }
    func fire() { beep(420, 0.12, 0.12, slide: 2.0) }
    func face() { beep(740, 0.14, 0.14); beep(980, 0.12, 0.1) }
    func win() { beep(523, 0.12, 0.12); beep(659, 0.12, 0.12); beep(784, 0.2, 0.14) }
    func lose() { beep(220, 0.28, 0.14, slide: 0.5) }
    func load() { beep(500, 0.05, 0.08) }
    func combo(_ n: Int) { beep(400 + Float(n) * 40, 0.1, 0.12) }

    private func beep(_ freq: Float, _ dur: Double, _ vol: Float, slide: Float = 1) {
        guard sfxOn, started else { return }
        tone(freq, dur: dur, volume: vol, slide: slide, to: sfx)
    }

    private func tone(_ freq: Float, dur: Double, volume: Float, slide: Float = 1, to mixer: AVAudioMixerNode) {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else { return }
        let count = Int(dur * format.sampleRate)
        guard count > 8, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        let ch = Int(format.channelCount)
        for i in 0..<count {
            let t = Float(i) / Float(count)
            let env = sin(Float.pi * min(1, t * 8)) * (1 - t)
            let f = freq * (1 + (slide - 1) * t)
            let s = sin(2 * Float.pi * f * Float(i) / Float(format.sampleRate)) * volume * env
            for c in 0..<ch { buffer.floatChannelData?[c][i] = s }
        }
        let player = AVAudioPlayerNode()
        engine.attach(player)
        engine.connect(player, to: mixer, format: format)
        player.scheduleBuffer(buffer, completionHandler: { [weak self, weak player] in
            guard let self, let player else { return }
            self.engine.disconnectNodeOutput(player)
            self.engine.detach(player)
        })
        player.play()
    }
}
