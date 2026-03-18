# シンプル文字起こし (OceanMoon)

リアルタイム音声文字起こしiOSアプリ。Apple SpeechAnalyzer (iOS 26) を使用し、直接の声だけでなくスピーカーからの音声も認識します。

## 機能

- リアルタイム文字起こし（タイムスタンプ付き）
- スピーカー経由の音声認識（リモート会議対応）
- セッション履歴の保存・閲覧
- セッションタイトルの編集
- 過去の文字起こしテキストの編集
- テキスト共有・エクスポート（タイトル・日時付き）
- 録音中の画面スリープ防止
- 完全オンデバイス処理（ネット接続不要）
- 日本語対応

## 要件

- iOS 26.0+
- Xcode 26.0+
- iPhone（マイク必須）
- 実機が必要（シミュレーターでは音声認識が動作しません）

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

### CLI からのビルド・インストール

```bash
# ビルド（実機向け）
xcodegen generate
xcodebuild -project OceanMoon.xcodeproj -scheme OceanMoon -destination 'id=<DEVICE_ID>' -allowProvisioningUpdates build

# デバイスにインストール
xcrun devicectl device install app --device <DEVICE_ID> <path_to_app>
```

デバイスIDは `xcrun xctrace list devices` で確認できます。

## 技術構成

- **音声認識**: Apple SpeechAnalyzer + SpeechTranscriber
- **UI**: SwiftUI
- **データ保存**: SwiftData
- **音声キャプチャ**: AVAudioEngine → AsyncStream\<AnalyzerInput\>

## ランディングページ

`lp/` ディレクトリに Next.js + Tailwind CSS で構築したランディングページがあります。

- **公開URL**: https://smoji.ddr8.com
- **デプロイ**: `cd lp && vercel --prod --yes`
- **ホスティング**: Vercel

## 制限事項

- 話者分離（Speaker Diarization）は iOS 26 の SpeechAnalyzer API では未対応
- シミュレーターでは音声認識機能が動作しないため、実機テストが必要

## ライセンス

MIT
