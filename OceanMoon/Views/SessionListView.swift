import SwiftUI
import SwiftData

struct SessionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Session.createdAt, order: .reverse) private var sessions: [Session]
    @State private var activeSession: Session?
    @State private var showingLive = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 履歴 header
                HStack {
                    Text("履歴")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(sessions.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 6)

                // Session list
                List {
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            SessionRowView(session: session)
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: deleteSessions)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                // 開始 button
                Button(action: startNewSession) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                            .font(.body.weight(.medium))
                        Text("開始")
                            .font(.body.weight(.medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("OceanMoon")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Session.self) { session in
                TranscriptionDetailView(session: session)
            }
            .fullScreenCover(isPresented: $showingLive) {
                if let activeSession {
                    LiveTranscriptionView(session: activeSession)
                }
            }
        }
    }

    private func startNewSession() {
        let session = Session()
        modelContext.insert(session)
        try? modelContext.save()
        activeSession = session
        showingLive = true
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
        try? modelContext.save()
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.preview.isEmpty ? "Empty Conversation" : session.preview)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    Text(formatDate(session.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if session.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm yyyy/MM/dd"
        return formatter.string(from: date)
    }
}
