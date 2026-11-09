import SwiftUI

enum DictationMode: Equatable {
    case dictation    // Обычная диктовка (красный микрофон, чистый Whisper)
    case translation  // Живой переводчик (сине-лазурный, RU ⇄ EN)
    case developer    // Режим разработчика (фиолетовый, Python код через openai/gpt-oss-120b)
}

enum HUDState: Equatable {
    case listening(level: Float, mode: DictationMode)
    case processing(stage: String, mode: DictationMode)
    case completed(message: String)
    case error(message: String)
}

@MainActor
final class FloatingHUDViewModel: ObservableObject {
    @Published var state: HUDState = .listening(level: 0, mode: .dictation)
}

struct FloatingHUDView: View {
    @ObservedObject var viewModel: FloatingHUDViewModel

    var body: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .listening(let level, let mode):
                switch mode {
                case .translation:
                    // РЕЖИМ ПЕРЕВОДЧИКА: Сине-голубой глобус и бейдж RU ⇄ EN
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.18))
                            .frame(width: 28, height: 28)
                            .scaleEffect(1.0 + CGFloat(level) * 0.35)
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6), value: level)
                        Image(systemName: "globe.europe.africa.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.65, blue: 1.0))
                    }
                    WaveformView(audioLevel: level, mode: .translation)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Froggy Переводчик")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Отпустите ⌘ для перевода")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                case .developer:
                    // РЕЖИМ РАЗРАБОТЧИКА: Фиолетовый значок кода и фиолетовая волна
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.65, green: 0.35, blue: 1.0).opacity(0.18))
                            .frame(width: 28, height: 28)
                            .scaleEffect(1.0 + CGFloat(level) * 0.35)
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6), value: level)
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Color(red: 0.65, green: 0.35, blue: 1.0))
                    }
                    WaveformView(audioLevel: level, mode: .developer)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Froggy Dev (Python)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Нажмите ⌘ для создания")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                case .dictation:
                    // РЕЖИМ ДИКТОВКИ: Красный микрофон и красная волна
                    ZStack {
                        Circle()
                            .fill(Color.red.opacity(0.18))
                            .frame(width: 26, height: 26)
                            .scaleEffect(1.0 + CGFloat(level) * 0.35)
                            .animation(.interactiveSpring(response: 0.2, dampingFraction: 0.6), value: level)
                        Image(systemName: "mic.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    WaveformView(audioLevel: level, mode: .dictation)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Froggy слушает...")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Нажмите ⌘ для вставки")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }

            case .processing(let stage, _):
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
                Text(stage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)

            case .completed(let msg):
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.green)
                Text(msg)
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
    }
}
