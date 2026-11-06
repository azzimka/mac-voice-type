import Foundation

/// Amplitude/duration gate, not a speech classifier: sustained noise can pass.
/// Measure in 10 ms windows so a key click cannot qualify an entire tap buffer.
final class RecordingSignalMeter {
    static let silenceThreshold: Float = 0.05
    static let minimumActiveDuration: TimeInterval = 0.12
    private let lock = NSLock()
    private var peak: Float = 0
    private var activeDuration: TimeInterval = 0
    private var windowSum: Float = 0
    private var windowCount = 0

    var peakAudioLevel: Float {
        lock.lock()
        defer { lock.unlock() }
        return peak
    }

    var hasSufficientSignal: Bool {
        lock.lock()
        defer { lock.unlock() }
        return peak >= Self.silenceThreshold &&
            activeDuration + 0.000001 >= Self.minimumActiveDuration
    }

    func observe(samples: UnsafeBufferPointer<Float>, sampleRate: Double) {
        guard sampleRate.isFinite, sampleRate > 0 else { return }
        let windowSize = max(1, Int(sampleRate * 0.01))
        lock.lock()
        defer { lock.unlock() }
        for sample in samples {
            windowSum += sample * sample
            windowCount += 1
            if windowCount == windowSize {
                let rms = sqrtf(windowSum / Float(windowCount))
                let effectiveRMS = max(0, rms - 0.001)
                let level = min(1, powf(effectiveRMS * 22, 0.60))
                peak = max(peak, level)
                if level >= Self.silenceThreshold {
                    activeDuration += Double(windowCount) / sampleRate
                }
                windowCount = 0
                windowSum = 0
            }
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }
        peak = 0
        activeDuration = 0
        windowSum = 0
        windowCount = 0
    }
}
