import SwiftUI

enum HUDState: Equatable {
    case listening(level: Float)
    case processing(stage: String)
    case completed
    case error(message: String)
}

/// Плавающий матовый HUD-виджет в стиле Apple Dynamic Island
struct FloatingHUDView: View {
    let state: HUDState

    var body: some View {
        HStack(spacing: 12) {
            switch state {
            case .listening(let level):
                // Пульсирующий индикатор записи
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.0 + CGFloat(level) * 0.4)
                        .animation(.easeInOut(duration: 0.2), value: level)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.red)
                }

                // Живая звуковая волна
                WaveformView(audioLevel: level)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Слушаю речь...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)

                    Text("Нажмите ⌘ для вставки")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                }

            case .processing(let stage):
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)

                Text(stage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)

                Text("Готово!")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)

            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.orange)

                Text(msg)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Матовое размытое стекло macOS
                Capsule()
                    .fill(.ultraThinMaterial)

                // Тонкая элегантная рамка с легким свечением
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
    }
}
