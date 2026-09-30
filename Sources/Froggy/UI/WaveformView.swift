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
        .frame(height: 20)
    }
}

private struct WaveBar: View {
    let audioLevel: Float
    let index: Int

    private var multiplier: CGFloat {
        switch index {
        case 0, 4: return 0.5
        case 1, 3: return 0.8
        default:   return 1.2
        }
    }

    var body: some View {
        let minH: CGFloat = 4
        let maxH: CGFloat = 20
        let h = max(minH, min(maxH, CGFloat(audioLevel) * maxH * multiplier + minH))

        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [Color.green, Color.green.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: h)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: audioLevel)
    }
}
