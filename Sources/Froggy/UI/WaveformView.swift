import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    var isTranslation: Bool = false
    private let barCount = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveBar(audioLevel: audioLevel, index: index, isTranslation: isTranslation)
            }
        }
        .frame(height: 24)
    }
}

private struct WaveBar: View {
    let audioLevel: Float
    let index: Int
    let isTranslation: Bool

    // Органичное распределение высоты столбиков для эффекта живого звукового купола
    private var weight: CGFloat {
        switch index {
        case 0, 4: return 0.55
        case 1, 3: return 0.95
        default:   return 1.40
        }
    }

    private var springDelay: Double {
        switch index {
        case 0, 4: return 0.025
        case 1, 3: return 0.012
        default:   return 0.0
        }
    }

    var body: some View {
        let minH: CGFloat = 4.0
        let maxH: CGFloat = 24.0
        let lvl = CGFloat(max(0.0, min(1.0, audioLevel)))
        let targetH = minH + lvl * (maxH - minH) * weight
        let h = max(minH, min(maxH, targetH))

        Capsule()
            .fill(
                LinearGradient(
                    colors: isTranslation
                        ? [Color(red: 0.15, green: 0.82, blue: 1.0), Color(red: 0.05, green: 0.48, blue: 0.98)]
                        : [Color(red: 1.0, green: 0.28, blue: 0.28), Color(red: 0.85, green: 0.12, blue: 0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3.5, height: h)
            .animation(
                .interactiveSpring(response: 0.13, dampingFraction: 0.55, blendDuration: 0.02).delay(springDelay),
                value: h
            )
    }
}
