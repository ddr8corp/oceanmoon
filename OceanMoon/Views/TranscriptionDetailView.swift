import SwiftUI

struct TranscriptionDetailView: View {
    let session: Session

    var body: some View {
        VStack(spacing: 0) {
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
                Text(formattedDuration)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
                    if sorted.isEmpty {
                        Text("文字起こしデータがありません")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(sorted) { utterance in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(utterance.formattedOffset)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(utterance.text)
                                    .font(.body)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .padding(.top, 8)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("OceanMoon")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: exportText(),
                    subject: Text(session.title),
                    message: Text("OceanMoonで文字起こし")
                )
            }
        }
    }

    private var formattedDuration: String {
        let total = Int(session.duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    private func exportText() -> String {
        let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
        return sorted.map { "\($0.formattedOffset)\n\($0.text)" }.joined(separator: "\n\n")
    }
}
