import SwiftUI

enum DictationMode: Equatable {
    case dictation    // Обычная диктовка (зелёная, исправление ошибок)
    case translation  // Живой переводчик (сине-лазурный, RU ⇄ EN)
}

enum HUDState: Equatable {
    case listening(level: Float, mode: DictationMode)
    case processing(stage: String, mode: DictationMode)
    case completed(message: String)
    case error(message: String)
}

@MainActor
final class FloatingHUDViewModel: ObservableObject {
    @Published var state: HUDState = .completed(message: "Готово!")
}

struct FloatingHUDView: View {
    @ObservedObject var viewModel: FloatingHUDViewModel

    var body: some View {
        HStack(spacing: 12) {
            switch viewModel.state {
            case .listening(let level, let mode):
                if mode == .translation {
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
                    WaveformView(audioLevel: level, isTranslation: true)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Froggy Переводчик")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                            Text("RU ⇄ EN")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1.5)
                                .background(Capsule().fill(Color.blue.opacity(0.18)))
                                .foregroundColor(Color(red: 0.0, green: 0.55, blue: 1.0))
                        }
                        Text("Отпустите ⌘ для перевода")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                } else {
                    // РЕЖИМ ДИКТОВКИ: Классический зеленый Froggy и красный микрофон
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
                    WaveformView(audioLevel: level, isTranslation: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Froggy слушает...")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Нажмите ⌘ для вставки")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundColor(.secondary)
                    }
                }

            case .processing(let stage, let mode):
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 20, height: 20)
                HStack(spacing: 6) {
                    Text(stage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.primary)
                    if mode == .translation {
                        Text("RU ⇄ EN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Capsule().fill(Color.blue.opacity(0.18)))
                            .foregroundColor(Color.blue)
                    }
                }

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
        .shadow(color: .black.opacity(0.25), radius: 16, x: 0, y: 8)
    }
}
