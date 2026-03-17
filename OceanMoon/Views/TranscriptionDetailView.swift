import SwiftUI

struct TranscriptionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: Session
    @State private var isEditingTitle = false
    @State private var editingTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            // Session header card
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .onTapGesture {
                            editingTitle = session.title
                            isEditingTitle = true
                        }
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
                                Text(utterance.formattedTimestamp)
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
        .navigationTitle("シンプル文字起こし")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: exportText(),
                    subject: Text(session.title),
                    message: Text("シンプル文字起こし")
                )
            }
        }
        .sheet(isPresented: $isEditingTitle) {
            NavigationStack {
                VStack(spacing: 0) {
                    TextEditor(text: $editingTitle)
                        .font(.body)
                        .padding(12)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(16)
                        .frame(maxHeight: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                .navigationTitle("タイトルを編集")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("キャンセル") {
                            isEditingTitle = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            session.title = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            try? modelContext.save()
                            isEditingTitle = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium])
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
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: date)
    }

    private func exportText() -> String {
        let sorted = session.utterances.sorted { $0.offsetSeconds < $1.offsetSeconds }
        let header = "【\(session.title)】\n\(formatDate(session.createdAt))\n"
        let body = sorted.map { "\($0.formattedTimestamp)\n\($0.text)" }.joined(separator: "\n\n")
        return header + "\n" + body
    }
}
