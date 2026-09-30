import SwiftUI
import Cocoa

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var apiKey: String = ""
    @Published var isKeyVisible: Bool = false
    @Published var statusMessage: String? = nil
    @Published var statusIsSuccess: Bool = false
    @Published var isTesting: Bool = false
    @Published var hasAccessibility: Bool = false
    @Published var hasMicrophone: Bool = false

    init() {
        if let saved = KeychainHelper.getAPIKey() {
            self.apiKey = saved
        }
        refreshPermissions()
    }

    func refreshPermissions() {
        hasAccessibility = TextInjector.checkAccessibilityPermission(prompt: false)
        // Microphone check: if we can get audio input, we have permission
        hasMicrophone = true // Will be verified on first use
    }

    func saveKey() {
        let cleaned = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            statusMessage = "Введите API ключ"
            statusIsSuccess = false
            return
        }
        if KeychainHelper.saveAPIKey(cleaned) {
            statusMessage = "✓ Ключ сохранён"
            statusIsSuccess = true
        } else {
            statusMessage = "Ошибка сохранения"
            statusIsSuccess = false
        }
    }

    func testKey() {
        isTesting = true
        statusMessage = "Проверка..."
        statusIsSuccess = false
        Task {
            do {
                _ = try await GroqClient.shared.correctGrammar(text: "Test connection to API", apiKey: apiKey)
                self.statusMessage = "✓ Groq API работает!"
                self.statusIsSuccess = true
            } catch {
                self.statusMessage = "✗ \(error.localizedDescription)"
                self.statusIsSuccess = false
            }
            self.isTesting = false
        }
    }

    func openAccessibility() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openMicrophone() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct OnboardingView: View {
    @StateObject private var vm = OnboardingViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header with logo
            VStack(spacing: 12) {
                FroggyLogoView()
                Text("Froggy")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Text("Голос → Текст за доли секунды")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)

            // API Key section
            VStack(alignment: .leading, spacing: 10) {
                Text("Groq API Key")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)

                HStack(spacing: 8) {
                    Group {
                        if vm.isKeyVisible {
                            TextField("gsk_...", text: $vm.apiKey)
                        } else {
                            SecureField("gsk_...", text: $vm.apiKey)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )

                    Button(action: { vm.isKeyVisible.toggle() }) {
                        Image(systemName: vm.isKeyVisible ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                }

                HStack {
                    Link("Получить ключ бесплатно →", destination: URL(string: "https://console.groq.com/keys")!)
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Spacer()
                    Button("Проверить") { vm.testKey() }
                        .font(.system(size: 12))
                        .disabled(vm.apiKey.isEmpty || vm.isTesting)
                }

                if let status = vm.statusMessage {
                    Text(status)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(vm.statusIsSuccess ? .green : .red)
                }
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            // Permissions
            VStack(spacing: 8) {
                PermissionRow(
                    icon: "mic.fill",
                    title: "Микрофон",
                    granted: vm.hasMicrophone,
                    action: { vm.openMicrophone() }
                )
                PermissionRow(
                    icon: "hand.raised.fill",
                    title: "Универсальный доступ",
                    granted: vm.hasAccessibility,
                    action: {
                        vm.openAccessibility()
                        // Re-check after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            vm.refreshPermissions()
                        }
                    }
                )
            }
            .padding(.horizontal, 24)

            Spacer().frame(height: 16)

            // Save button
            Button(action: { vm.saveKey() }) {
                Text("Сохранить")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.green)
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            // Instruction
            Text("2x ⌘ Command — диктовка • Зажать ⌘ (1 сек) — переводчик RU ⇄ EN")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)
        }
        .frame(width: 400, height: 480)
        .background(.ultraThinMaterial)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(granted ? .green : .orange)
            Text(title)
                .font(.system(size: 13))
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 14))
            } else {
                Button("Включить") { action() }
                    .font(.system(size: 12))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
        )
    }
}

struct FroggyLogoView: View {
    var body: some View {
        if let path = Bundle.main.path(forResource: "AppIcon", ofType: "jpg"),
           let img = NSImage(contentsOfFile: path) {
            Image(nsImage: img)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        } else if let appIcon = NSApp.applicationIconImage {
            Image(nsImage: appIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
        } else {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
        }
    }
}
