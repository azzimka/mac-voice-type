#!/bin/bash
set -e

echo "🐸 Сборка Froggy..."

# Очистка кэша
rm -rf .build

# Компиляция в Release
swift build -c release

APP_DIR="Froggy.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

BIN_PATH=$(swift build -c release --show-bin-path)/Froggy
cp "$BIN_PATH" "$MACOS_DIR/Froggy"

# Копируем лого
if [ -f "Resources/AppIcon.jpg" ]; then
    cp Resources/AppIcon.jpg "$RESOURCES_DIR/AppIcon.jpg"
    # Конвертируем jpg в icns через sips
    sips -s format png "Resources/AppIcon.jpg" --out "$RESOURCES_DIR/AppIcon.png" 2>/dev/null || true
    mkdir -p "$RESOURCES_DIR/AppIcon.iconset"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$RESOURCES_DIR/AppIcon.png" --out "$RESOURCES_DIR/AppIcon.iconset/icon_${size}x${size}.png" 2>/dev/null || true
    done
    for size in 16 32 64 128 256; do
        double=$((size * 2))
        sips -z $double $double "$RESOURCES_DIR/AppIcon.png" --out "$RESOURCES_DIR/AppIcon.iconset/icon_${size}x${size}@2x.png" 2>/dev/null || true
    done
    iconutil -c icns "$RESOURCES_DIR/AppIcon.iconset" -o "$RESOURCES_DIR/AppIcon.icns" 2>/dev/null || true
    rm -rf "$RESOURCES_DIR/AppIcon.iconset" "$RESOURCES_DIR/AppIcon.png"
fi

cat <<EOF > "$CONTENTS_DIR/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Froggy</string>
    <key>CFBundleIdentifier</key>
    <string>com.froggy.app</string>
    <key>CFBundleName</key>
    <string>Froggy</string>
    <key>CFBundleDisplayName</key>
    <string>Froggy</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
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
    <string>Froggy записывает вашу речь для перевода голоса в текст.</string>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>Froggy использует распознавание речи.</string>
</dict>
</plist>
EOF

codesign --force --deep -s - -r='designated => identifier "com.froggy.app"' "$APP_DIR"

echo "✅ Готово! Приложение: $APP_DIR"
echo "👉 Запуск: open Froggy.app"
