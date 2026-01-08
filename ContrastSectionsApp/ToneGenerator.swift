import AVFoundation
import AudioToolbox

class ToneGenerator: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var mixerNode: AVAudioMixerNode?
    private let format: AVAudioFormat = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    
    init() {
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        playerNode = AVAudioPlayerNode()
        mixerNode = audioEngine?.mainMixerNode
        
        guard let audioEngine = audioEngine,
              let playerNode = playerNode,
              let mixerNode = mixerNode else { return }
        
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: mixerNode, format: format)
        
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
        
        if audioEngine.isRunning {
            playerNode.play()
        }
    }
    
    func playTone(frequency: Double, duration: Double = 0.3) {
        guard let playerNode = playerNode,
              let _ = mixerNode else { return }
        
        let sampleRate = format.sampleRate
        let frameCount = Int(sampleRate * duration)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        let channelData = buffer.floatChannelData![0]
        
        // Piano-like harmonics with reduced amplitudes for better blending
        let harmonics: [(frequency: Double, amplitude: Double)] = [
            (frequency * 1.0, 1.0),      // Fundamental (strongest)
            (frequency * 2.0, 0.3),     // 2nd harmonic (octave) - reduced
            (frequency * 3.0, 0.15),    // 3rd harmonic - reduced
            (frequency * 4.0, 0.08)     // 4th harmonic - reduced
        ]
        
        // Normalize: sum of amplitudes for consistent volume
        let amplitudeSum = harmonics.reduce(0.0) { $0 + $1.amplitude }
        let normalizationFactor = 1.0 / amplitudeSum
        
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            
            // Sum all harmonics with normalization
            var sample: Double = 0.0
            for harmonic in harmonics {
                sample += harmonic.amplitude * sin(2.0 * Double.pi * harmonic.frequency * time)
            }
            sample *= normalizationFactor
            
            // Apply smooth envelope: gradual attack, very gentle decay
            let attackTime = 0.02 // 20ms attack (smoother)
            let envelope: Double
            
            if time < attackTime {
                // Attack phase: smooth exponential curve (not linear)
                let attackProgress = time / attackTime
                // Use a smooth curve: 1 - e^(-x*3) gives a smooth rise
                envelope = 1.0 - exp(-attackProgress * 3.0)
            } else {
                // Decay phase: very gentle exponential decay
                let decayProgress = (time - attackTime) / (duration - attackTime)
                // Much gentler decay for smoother sound
                envelope = 1.0 * exp(-decayProgress * 0.8)
            }
            
            channelData[frame] = Float(sample * envelope * 0.3) // Overall volume
        }
        
        if playerNode.isPlaying == false {
            playerNode.play()
        }
        playerNode.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
    }
    
    deinit {
        audioEngine?.stop()
    }
}
