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
                // Header
                HStack {
                    Text("履歴")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(sessions.count)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Session list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(sessions) { session in
                            NavigationLink(value: session) {
                                SessionRowView(session: session)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteSessions)
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Start button
                Button(action: startNewSession) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.right")
                        Text("開始")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray6))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
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
    }
}

struct SessionRowView: View {
    let session: Session

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.preview.isEmpty ? "Empty Conversation" : session.preview)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                Text(session.createdAt.formatted(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if session.isActive {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    }
}
