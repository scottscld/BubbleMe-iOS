import AVFoundation
import Foundation

/// Procedural music + SFX (same idea as bubbleme.fun). No audio files required.
/// Player nodes stay attached — never disconnect from the audio thread
/// (that was crashing the simulator with EXC_BREAKPOINT).
final class AudioEngine {
    static let shared = AudioEngine()
    private let engine = AVAudioEngine()
    private let sfx = AVAudioMixerNode()
    private let music = AVAudioMixerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var sfxPool: [AVAudioPlayerNode] = []
    private var musicPool: [AVAudioPlayerNode] = []
    private var sfxIndex = 0
    private var musicIndex = 0
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
        engine.connect(sfx, to: engine.mainMixerNode, format: format)
        engine.connect(music, to: engine.mainMixerNode, format: format)
        sfxPool = makePool(count: 8, mixer: sfx)
        musicPool = makePool(count: 2, mixer: music)
        sfx.outputVolume = 1
        music.outputVolume = musicOn ? 0.18 : 0
        do {
            try engine.start()
            started = true
            startMusic()
        } catch {
            started = false
        }
    }

    func stopMusic() {
        musicTimer?.invalidate()
        musicTimer = nil
    }

    private func makePool(count: Int, mixer: AVAudioMixerNode) -> [AVAudioPlayerNode] {
        (0..<count).map { _ in
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: mixer, format: format)
            return player
        }
    }

    private func startMusic() {
        stopMusic()
        let notes: [Float] = [261.6, 329.6, 392.0, 493.9, 523.3, 493.9, 392.0, 329.6]
        let t = Timer(timeInterval: 0.42, repeats: true) { [weak self] _ in
            guard let self, self.musicOn, self.started, self.engine.isRunning else { return }
            let f = notes[self.step % notes.count]
            self.step += 1
            self.tone(f, dur: 0.28, volume: 0.05, toMusic: true)
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
        let work = { self.tone(freq, dur: dur, volume: vol, slide: slide, toMusic: false) }
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func tone(_ freq: Float, dur: Double, volume: Float, slide: Float = 1, toMusic: Bool) {
        guard engine.isRunning else { return }
        let rate = Float(format.sampleRate)
        let count = Int(dur * Double(rate))
        guard count > 8, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)) else { return }
        buffer.frameLength = AVAudioFrameCount(count)
        guard let samples = buffer.floatChannelData?[0] else { return }
        for i in 0..<count {
            let t = Float(i) / Float(count)
            let env = sin(Float.pi * min(1, t * 8)) * (1 - t)
            let f = freq * (1 + (slide - 1) * t)
            samples[i] = sin(2 * Float.pi * f * Float(i) / rate) * volume * env
        }
        let pool = toMusic ? musicPool : sfxPool
        guard !pool.isEmpty else { return }
        if toMusic {
            musicIndex = (musicIndex + 1) % pool.count
        } else {
            sfxIndex = (sfxIndex + 1) % pool.count
        }
        let player = pool[toMusic ? musicIndex : sfxIndex]
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }
}
