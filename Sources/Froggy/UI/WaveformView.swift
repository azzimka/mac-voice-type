import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    private let barCount = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveBar(audioLevel: audioLevel, index: index)
            }
        }
        .frame(height: 22)
    }
}

private struct WaveBar: View {
    let audioLevel: Float
    let index: Int

    private var weight: CGFloat {
        switch index {
        case 0, 4: return 0.5
        case 1, 3: return 0.85
        default:   return 1.3
        }
    }

    private var springDelay: Double {
        switch index {
        case 0, 4: return 0.04
        case 1, 3: return 0.02
        default:   return 0.0
        }
    }

    var body: some View {
        let minH: CGFloat = 4.0
        let maxH: CGFloat = 22.0
        let targetH = minH + CGFloat(audioLevel) * (maxH - minH) * weight
        let h = max(minH, min(maxH, targetH))

        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.22, green: 0.85, blue: 0.42),
                        Color(red: 0.12, green: 0.68, blue: 0.32)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3.5, height: h)
            .animation(
                .spring(response: 0.2, dampingFraction: 0.6, blendDuration: 0.05).delay(springDelay),
                value: h
            )
    }
}
