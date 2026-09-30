#!/bin/bash
set -e

echo "🚀 Сборка MacVoiceType..."

# 1. Компиляция в Release конфигурации
swift build -c release

# 2. Создание структуры .app бандла
APP_DIR="MacVoiceType.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# 3. Копирование скомпилированного бинарника
BIN_PATH=$(swift build -c release --show-bin-path)/MacVoiceType
cp "$BIN_PATH" "$MACOS_DIR/MacVoiceType"

# 4. Генерация Info.plist
cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacVoiceType</string>
    <key>CFBundleIdentifier</key>
    <string>com.macvoicetype.app</string>
    <key>CFBundleName</key>
    <string>Mac Voice Type</string>
    <key>CFBundleDisplayName</key>
    <string>Mac Voice Type</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Mac Voice Type необходим доступ к микрофону для диктовки текста.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Mac Voice Type использует распознавание речи для перевода голоса в текст.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Приложению требуется доступ для вставки текста в активное поле ввода.</string>
</dict>
</plist>
EOF

# 5. Ad-hoc подпись бинарника (для macOS Gatekeeper и прав доступа)
codesign --force --deep --sign - "$APP_DIR"

echo "✅ Успешно! Создано готовое приложение: $APP_DIR"
echo "👉 Чтобы запустить, выполните: open MacVoiceType.app"
