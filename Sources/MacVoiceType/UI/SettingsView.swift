import SwiftUI

/// ViewModel для настроек с использованием Combine ObservableObject (без зависимости от макросов)
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var isKeyVisible: Bool = false
    @Published var enableGrammarCorrection: Bool = UserDefaults.standard.bool(forKey: "enable_grammar_correction")
    @Published var whisperModel: String = UserDefaults.standard.string(forKey: "whisper_model") ?? "whisper-large-v3-turbo"
    @Published var saveStatus: String? = nil
    @Published var isTesting: Bool = false

    init() {
        if let saved = KeychainHelper.getAPIKey() {
            self.apiKey = saved
        }
        if UserDefaults.standard.object(forKey: "enable_grammar_correction") == nil {
            UserDefaults.standard.set(true, forKey: "enable_grammar_correction")
            self.enableGrammarCorrection = true
        }
    }

    func saveKey() {
        let cleaned = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainHelper.saveAPIKey(cleaned) {
            saveStatus = "Ключ успешно сохранен в Apple Keychain!"
        } else {
            saveStatus = "Ошибка сохранения ключа в Keychain."
        }
    }

    func testConnection() {
        isTesting = true
        saveStatus = "Проверка ключа..."
        Task {
            do {
                _ = try await GroqClient.shared.correctGrammar(text: "Привет", apiKey: apiKey)
                self.saveStatus = "Groq API успешно работает!"
                self.isTesting = false
            } catch {
                self.saveStatus = "Ошибка проверки: \(error.localizedDescription)"
                self.isTesting = false
            }
        }
    }

    func updateGrammarCorrection(_ value: Bool) {
        enableGrammarCorrection = value
        UserDefaults.standard.set(value, forKey: "enable_grammar_correction")
    }

    func updateWhisperModel(_ value: String) {
        whisperModel = value
        UserDefaults.standard.set(value, forKey: "whisper_model")
    }
}

/// Окно настроек приложения
struct SettingsView: View {
    @StateObject private var vm = SettingsViewModel()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Groq API Key")
                        .font(.headline)

                    HStack {
                        if vm.isKeyVisible {
                            TextField("gsk_...", text: $vm.apiKey)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField("gsk_...", text: $vm.apiKey)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button(action: { vm.isKeyVisible.toggle() }) {
                            Image(systemName: vm.isKeyVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)

                        Button("Сохранить") {
                            vm.saveKey()
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    HStack {
                        Link("Получить бесплатный ключ на console.groq.com", destination: URL(string: "https://console.groq.com/keys")!)
                            .font(.caption)
                            .foregroundColor(.accentColor)

                        Spacer()

                        Button("Проверить ключ") {
                            vm.testConnection()
                        }
                        .font(.caption)
                        .disabled(vm.apiKey.isEmpty || vm.isTesting)
                    }

                    if let status = vm.saveStatus {
                        Text(status)
                            .font(.caption)
                            .foregroundColor(status.contains("успешно") || status.contains("работает") ? .green : .red)
                            .padding(.top, 2)
                    }
                }
            }

            Section {
                Toggle("Исправлять грамматику и пунктуацию (Llama 3.3)", isOn: Binding(
                    get: { vm.enableGrammarCorrection },
                    set: { vm.updateGrammarCorrection($0) }
                ))

                Picker("Модель распознавания речи (STT):", selection: Binding(
                    get: { vm.whisperModel },
                    set: { vm.updateWhisperModel($0) }
                )) {
                    Text("Whisper Large v3 Turbo (Сверхбыстрая ~200мс)").tag("whisper-large-v3-turbo")
                    Text("Whisper Large v3 (Максимальная точность)").tag("whisper-large-v3")
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Системные разрешения")
                        .font(.headline)

                    HStack {
                        Text("Универсальный доступ (Accessibility):")
                        Spacer()
                        Button("Открыть настройки macOS") {
                            openAccessibilitySettings()
                        }
                    }

                    HStack {
                        Text("Микрофон:")
                        Spacer()
                        Button("Открыть настройки микрофона") {
                            openMicrophoneSettings()
                        }
                    }

                    Text("Для перехвата двойного нажатия ⌘ и вставки текста через Cmd+V приложению необходим доступ в 'Универсальном доступе'.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 520, height: 380)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
