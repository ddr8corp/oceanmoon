import SwiftUI
import SwiftData

struct LiveTranscriptionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var session: Session
    @State private var speechService = SpeechRecognitionService()
    @State private var showError: String?

    var body: some View {
        VStack(spacing: 0) {
            // Nav bar
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
                Color.clear.frame(width: 24, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            // Session header card
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(formatDate(session.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(speechService.isPaused ? .orange : .green)
                        .frame(width: 8, height: 8)
                    Text(formattedElapsed)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)

            // 文字起こし tab header
            HStack {
                VStack(spacing: 4) {
                    Text("文字起こし")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Rectangle()
                        .fill(.primary)
                        .frame(height: 2)
                        .frame(width: 80)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 4)

            // Transcription content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
                        ForEach(sorted) { utterance in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(utterance.formattedOffset)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(utterance.text)
                                    .font(.subheadline)
                            }
                            .id(utterance.id)
                        }

                        if !speechService.currentText.isEmpty {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(formattedElapsed)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(speechService.currentText)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .id("current")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                }
                .onChange(of: session.utterances.count) {
                    if let last = session.utterances.sorted(by: { $0.offsetSeconds < $1.offsetSeconds }).last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: speechService.currentText) {
                    proxy.scrollTo("current", anchor: .bottom)
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer(minLength: 8)

            // Bottom controls
            HStack(spacing: 10) {
                Button(action: togglePause) {
                    HStack(spacing: 6) {
                        Image(systemName: speechService.isPaused ? "play.fill" : "pause.fill")
                            .font(.caption)
                        Text(speechService.isPaused ? "再開" : "一時停止")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button(action: stopAndDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.caption)
                        Text("終了")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(.light)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private func startRecognition() async {
        let authorized = await speechService.requestAuthorization()
        guard authorized else {
            showError = "音声認識の許可が必要です。設定アプリから許可してください。"
            return
        }

        let context = modelContext
        let currentSession = session
        speechService.onUtteranceFinalized = { text, offset in
            let utterance = Utterance(
                text: text,
                offsetSeconds: offset
            )
            currentSession.utterances.append(utterance)
            try? context.save()
        }

        speechService.start()
    }

    private func togglePause() {
        if speechService.isPaused {
            speechService.resume()
        } else {
            speechService.pause()
        }
    }

    private func stopAndDismiss() {
        speechService.stop()
        session.isActive = false

        if session.title == "新しい会話", !session.preview.isEmpty {
            let preview = session.preview
            session.title = String(preview.prefix(30))
        }

        try? modelContext.save()
        dismiss()
    }
}
