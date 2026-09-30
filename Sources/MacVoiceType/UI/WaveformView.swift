import SwiftUI

/// Анимированная звуковая волна в стиле Apple Intelligence
struct WaveformView: View {
    let audioLevel: Float // 0.0 ... 1.0

    // 5 вертикальных полосок с разной чувствительностью
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

    // Множитель высоты для создания органичной волны (по центру выше, по краям ниже)
    private var multiplier: CGFloat {
        switch index {
        case 0, 4: return 0.5
        case 1, 3: return 0.8
        default:   return 1.2
        }
    }

    var body: some View {
        let minHeight: CGFloat = 4
        let maxHeight: CGFloat = 20
        let targetHeight = max(minHeight, min(maxHeight, CGFloat(audioLevel) * maxHeight * multiplier + minHeight))

        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.7, blue: 1.0),
                        Color(red: 0.6, green: 0.3, blue: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 3, height: targetHeight)
            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.6), value: audioLevel)
    }
}
