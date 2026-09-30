import Foundation

/// Хранилище настроек Froggy: быстрый доступ без системных запросов пароля macOS
enum KeychainHelper {
    private static let keyName = "froggy_groq_api_key"
    private static var cachedKey: String? = nil

    @discardableResult
    static func saveAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        cachedKey = trimmed
        UserDefaults.standard.set(trimmed, forKey: keyName)
        print("[Froggy] API key saved successfully to UserDefaults")
        return true
    }

    static func getAPIKey() -> String? {
        if let mem = cachedKey, !mem.isEmpty {
            return mem
        }
        if let stored = UserDefaults.standard.string(forKey: keyName), !stored.isEmpty {
            cachedKey = stored
            return stored
        }
        return nil
    }

    @discardableResult
    static func deleteAPIKey() -> Bool {
        cachedKey = nil
        UserDefaults.standard.removeObject(forKey: keyName)
        return true
    }
}
