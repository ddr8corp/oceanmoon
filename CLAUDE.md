# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

「シンプル文字起こし」(OceanMoon) はリアルタイム音声文字起こし iOS アプリ。Apple SpeechAnalyzer (iOS 26) を使用し、直接の声とスピーカー経由の音声を認識する。完全オンデバイス処理。アプリ表示名は「シンプル文字起こし」、ホーム画面のアイコン下は「文字起こし」。

## ビルド・開発コマンド

```bash
# プロジェクトファイル生成（project.yml から .xcodeproj を生成）
xcodegen generate

# Xcode で開く
open OceanMoon.xcodeproj

# CLI ビルド（実機向け、DEVICE_ID は xcrun xctrace list devices で確認）
xcodebuild -project OceanMoon.xcodeproj -scheme OceanMoon -destination 'id=<DEVICE_ID>' -allowProvisioningUpdates build

# デバイスにインストール
xcrun devicectl device install app --device <DEVICE_ID> <path_to_built_app>
```

- `.xcodeproj` は gitignore 対象。`project.yml` を編集後は必ず `xcodegen generate` を再実行
- シミュレーターでは音声認識が動作しないため実機が必要
- `project.yml` に `DEVELOPMENT_TEAM` が設定済み

## 技術スタック

- **Swift 6.0** (Strict Concurrency: complete)
- **iOS 26.0+** 専用（最低デプロイメントターゲット）
- **SwiftUI** + **SwiftData** (外部依存なし)
- **音声認識**: SpeechAnalyzer + SpeechTranscriber + AVAudioEngine

## アーキテクチャ

3層構造: Models → Services → Views

```
OceanMoonApp (エントリーポイント、SwiftData modelContainer 設定)
    ↓
SessionListView ──→ TranscriptionDetailView (過去セッション閲覧・編集・共有)
    ↓ (新規セッション作成)
LiveTranscriptionView ──→ SpeechRecognitionService (音声認識エンジン)
    ↓ onUtteranceFinalized コールバック
Session.utterances に Utterance 追加 → SwiftData 保存
```

- **Session** (`@Model`): 文字起こしセッション。`utterances` を1対多で保持（カスケード削除）。デフォルトタイトルは「新しい議事録」
- **Utterance** (`@Model`): 個別の発言。テキスト・タイムスタンプ・話者インデックスを持つ。`formattedTimestamp` で「HH:mm:ss (経過時間)」形式の表示
- **SpeechRecognitionService** (`@Observable`): AVAudioEngine でマイク入力をキャプチャし、SpeechTranscriber で認識。2秒の無音で発言を自動確定。重複防止に `segmentFinalized` フラグと `lastFinalizedText` を使用
- **LiveTranscriptionView**: fullScreenCover でモーダル表示。SpeechRecognitionService を所有し、確定した Utterance を Session に追加。録音中は画面スリープを防止
- **SessionListView**: `@Query` で全セッションを取得。セッションタイトルを一覧表示
- **TranscriptionDetailView**: セッションタイトルと発言テキストの編集、ShareLink によるエクスポート（タイトル・日時をヘッダーに含む）

## App Store 関連

- **バンドルID**: `com.ddr8.simple-transcription`
- **SKU**: `simple-transcription`
- **Team ID**: `54QB3RW3YS` (ddr8 co., ltd.)

### TestFlight / App Store アップロード

```bash
# アーカイブ作成
xcodegen generate
xcodebuild -project OceanMoon.xcodeproj -scheme OceanMoon -destination 'generic/platform=iOS' -archivePath /tmp/OceanMoon.xcarchive archive -allowProvisioningUpdates

# App Store Connect にアップロード（ExportOptions.plist が必要）
xcodebuild -exportArchive -archivePath /tmp/OceanMoon.xcarchive -exportOptionsPlist /tmp/ExportOptions.plist -exportPath /tmp/OceanMoonExport -allowProvisioningUpdates
```

ExportOptions.plist の内容:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>destination</key>
    <string>upload</string>
    <key>teamID</key>
    <string>54QB3RW3YS</string>
</dict>
</plist>
```

## ランディングページ (lp/)

- **URL**: https://smoji.ddr8.com
- **技術**: Next.js + Tailwind CSS (`lp/` ディレクトリ)
- **ホスティング**: Vercel (ddr8-projects)
- **カスタムドメイン**: `smoji.ddr8.com` (CNAME → Vercel)

### LP デプロイ

```bash
cd lp
vercel --prod --yes
```

- LP のアイコン画像は `lp/public/icon.png`（アプリアイコンと同じ）
- プライバシーポリシーは LP 内に掲載 (`#privacy`)
- サポート・問い合わせ先: https://www.ddr8.co.jp/

## 注意点

- Info.plist にマイクと音声認識の使用理由が日本語で記述されている（変更時は日本語を維持）
- `CFBundleDisplayName` は「文字起こし」（ホーム画面アイコン下の表示名）
- UI はライトモード固定（OceanMoonApp で `.preferredColorScheme(.light)` を設定）
- ボタンは黒背景・白文字で統一
- アプリアイコンはアルファチャンネルなし（透過があると iOS で薄く表示される）
- 話者分離（Speaker Diarization）は iOS 26 の SpeechAnalyzer API では未対応
