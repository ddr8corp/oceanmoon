# OceanMoon

リアルタイム音声文字起こしiOSアプリ。Apple SpeechAnalyzer (iOS 26) を使用し、直接の声だけでなくスピーカーからの音声も認識します。

## 機能

- リアルタイム文字起こし（タイムスタンプ付き）
- スピーカー経由の音声認識（リモート会議対応）
- セッション履歴の保存・閲覧
- テキスト共有・エクスポート
- 完全オンデバイス処理（ネット接続不要）
- 日本語対応

## 要件

- iOS 26.0+
- Xcode 26.0+
- iPhone（マイク必須）

## セットアップ

```bash
# xcodegen のインストール（未インストールの場合）
brew install xcodegen

# プロジェクト生成
xcodegen generate

# Xcodeで開く
open OceanMoon.xcodeproj
```

Xcode で Signing & Capabilities から Team を設定し、実機にビルドしてください。

## 技術構成

- **音声認識**: Apple SpeechAnalyzer + SpeechTranscriber
- **UI**: SwiftUI
- **データ保存**: SwiftData
- **音声キャプチャ**: AVAudioEngine → AsyncStream\<AnalyzerInput\>

## ライセンス

MIT
