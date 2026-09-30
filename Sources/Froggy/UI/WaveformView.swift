import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    var isTranslation: Bool = false
    private let barCount = 7

    var body: some View {
        HStack(spacing: 2.5) {
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

    // Высокочувствительное распределение высоты:
    // Центральные столбики дают мощный выразительный всплеск, крайние плавно следуют за ними
    private var weight: CGFloat {
        switch index {
        case 0, 6: return 0.50
        case 1, 5: return 0.85
        case 2, 4: return 1.25
        default:   return 1.60
        }
    }

    private var springDelay: Double {
        switch index {
        case 0, 6: return 0.024
        case 1, 5: return 0.012
        case 2, 4: return 0.004
        default:   return 0.0
        }
    }

    var body: some View {
        let minH: CGFloat = 3.5
        let maxH: CGFloat = 24.0
        let lvl = CGFloat(max(0.0, min(1.0, audioLevel)))
        let targetH = minH + lvl * (maxH - minH) * weight
        let h = max(minH, min(maxH, targetH))

        Capsule()
            .fill(
                LinearGradient(
                    colors: isTranslation
                        ? [Color(red: 0.20, green: 0.85, blue: 1.0), Color(red: 0.05, green: 0.50, blue: 0.98)]
                        : [Color(red: 1.0, green: 0.32, blue: 0.32), Color(red: 0.90, green: 0.12, blue: 0.18)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3.0, height: h)
            .animation(
                .interactiveSpring(response: 0.11, dampingFraction: 0.48, blendDuration: 0.015).delay(springDelay),
                value: h
            )
    }
}
