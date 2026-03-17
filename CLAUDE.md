# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## プロジェクト概要

「シンプル文字起こし」(OceanMoon) はリアルタイム音声文字起こし iOS アプリ。Apple SpeechAnalyzer (iOS 26) を使用し、直接の声とスピーカー経由の音声を認識する。完全オンデバイス処理。アプリ表示名は「シンプル文字起こし」。

## ビルド・開発コマンド

```bash
# プロジェクトファイル生成（project.yml から .xcodeproj を生成）
xcodegen generate

# Xcode で開く
open OceanMoon.xcodeproj

# CLI ビルド
xcodebuild -project OceanMoon.xcodeproj -scheme OceanMoon -destination 'generic/platform=iOS' build
```

- `.xcodeproj` は gitignore 対象。`project.yml` を編集後は必ず `xcodegen generate` を再実行
- 実機テストには Xcode で Signing Team の設定が必要

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
SessionListView ──→ TranscriptionDetailView (過去セッション閲覧・共有)
    ↓ (新規セッション作成)
LiveTranscriptionView ──→ SpeechRecognitionService (音声認識エンジン)
    ↓ onUtteranceFinalized コールバック
Session.utterances に Utterance 追加 → SwiftData 保存
```

- **Session** (`@Model`): 文字起こしセッション。`utterances` を1対多で保持（カスケード削除）
- **Utterance** (`@Model`): 個別の発言。テキスト・タイムスタンプ・話者インデックスを持つ
- **SpeechRecognitionService** (`@Observable`): AVAudioEngine でマイク入力をキャプチャし、SpeechTranscriber で認識。2秒の無音で発言を自動確定
- **LiveTranscriptionView**: fullScreenCover でモーダル表示。SpeechRecognitionService を所有し、確定した Utterance を Session に追加
- **SessionListView**: `@Query` で全セッションを取得。メインナビゲーションハブ
- **TranscriptionDetailView**: セッション内容の閲覧・ShareLink によるエクスポート

## 注意点

- Info.plist にマイクと音声認識の使用理由が日本語で記述されている（変更時は日本語を維持）
- UI はライトモード固定（OceanMoonApp で `.preferredColorScheme(.light)` を設定）
- entitlements ファイルは現在空だが、プロジェクト設定で参照されている
