import SwiftUI

enum HUDState: Equatable {
    case listening(level: Float)
    case processing(stage: String)
    case completed
    case error(message: String)
}

struct FloatingHUDView: View {
    let state: HUDState

    var body: some View {
        HStack(spacing: 12) {
            switch state {
            case .listening(let level):
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .scaleEffect(1.0 + CGFloat(level) * 0.4)
                        .animation(.easeInOut(duration: 0.2), value: level)
                    Text("🐸")
                        .font(.system(size: 14))
                }
                WaveformView(audioLevel: level)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Froggy слушает...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Нажмите ⌘ для вставки")
                        .font(.system(size: 10))
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

            case .error(let msg):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                Text(msg)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1
                )
            }
        )
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}
