import SwiftUI

struct TranscriptionDetailView: View {
    let session: Session

    var body: some View {
        VStack(spacing: 0) {
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
                Text(formattedDuration)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 8)

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
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
                    if sorted.isEmpty {
                        Text("文字起こしデータがありません")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    } else {
                        ForEach(sorted) { utterance in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(utterance.formattedOffset)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(utterance.text)
                                    .font(.subheadline)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .preferredColorScheme(.light)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm yyyy/MM/dd"
        return formatter.string(from: date)
    }

    private func exportText() -> String {
        let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
        return sorted.map { "\($0.formattedOffset)\n\($0.text)" }.joined(separator: "\n\n")
    }
}
