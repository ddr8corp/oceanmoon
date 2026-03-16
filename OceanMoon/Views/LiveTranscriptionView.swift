import SwiftUI
import SwiftData

struct LiveTranscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: Session
    @State private var speechService = SpeechRecognitionService()
    @State private var showError: String?
    @State private var hasAuthorization = false

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: { stopAndDismiss() }) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("OceanMoon")
                    .font(.headline)
                Spacer()
                Color.clear.frame(width: 24)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)

            // Session header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(session.createdAt.formatted(date: .numeric, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(speechService.isPaused ? .orange : .green)
                        .frame(width: 8, height: 8)
                    Text(formattedElapsed)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
            .padding(.horizontal)

            // Tab header
            HStack {
                Text("文字起こし")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.top, 16)
            .padding(.bottom, 4)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.primary)
                    .frame(height: 2)
                    .offset(y: 2)
            }

            // Transcription content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
                        ForEach(sorted) { utterance in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(utterance.formattedOffset)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(utterance.text)
                                    .font(.body)
                            }
                            .id(utterance.id)
                        }

                        // Current partial text
                        if !speechService.currentText.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formattedElapsed)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(speechService.currentText)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            .id("current")
                        }
                    }
                    .padding()
                }
                .onChange(of: session.utterances.count) {
                    if let last = session.utterances.sorted(by: { $0.offsetSeconds < $1.offsetSeconds }).last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: speechService.currentText) {
                    withAnimation {
                        proxy.scrollTo("current", anchor: .bottom)
                    }
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            // Bottom controls
            HStack(spacing: 12) {
                Button(action: togglePause) {
                    HStack(spacing: 6) {
                        Image(systemName: speechService.isPaused ? "play.fill" : "pause.fill")
                        Text(speechService.isPaused ? "再開" : "一時停止")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: stopAndDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                        Text("終了")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            await startRecognition()
        }
        .alert("エラー", isPresented: .init(
            get: { showError != nil },
            set: { if !$0 { showError = nil } }
        )) {
            Button("OK") { showError = nil }
        } message: {
            Text(showError ?? "")
        }
    }

    private var formattedElapsed: String {
        let total = Int(speechService.elapsedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func startRecognition() async {
        let authorized = await speechService.requestAuthorization()
        guard authorized else {
            showError = "音声認識の許可が必要です。設定アプリから許可してください。"
            return
        }

        speechService.onUtteranceFinalized = { text, offset in
            let utterance = Utterance(
                text: text,
                offsetSeconds: offset
            )
            session.utterances.append(utterance)
            try? modelContext.save()
        }

        do {
            try speechService.start()
        } catch {
            showError = error.localizedDescription
        }
    }

    private func togglePause() {
        if speechService.isPaused {
            try? speechService.resume()
        } else {
            speechService.pause()
        }
    }

    private func stopAndDismiss() {
        speechService.stop()
        session.isActive = false

        // Set title from first utterance content
        if session.title == "新しい会話", !session.preview.isEmpty {
            let preview = session.preview
            session.title = String(preview.prefix(30))
        }

        try? modelContext.save()
        dismiss()
    }
}
