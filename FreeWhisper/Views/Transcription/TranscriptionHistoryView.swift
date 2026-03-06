import SwiftUI

struct TranscriptionHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if !appState.transcriptionHistory.isEmpty {
                    Button("Clear All") {
                        appState.transcriptionHistory.removeAll()
                    }
                    .font(.caption)
                }
            }
            .padding(.horizontal)

            if appState.transcriptionHistory.isEmpty {
                ContentUnavailableView(
                    "No Transcriptions Yet",
                    systemImage: "text.bubble",
                    description: Text("Your transcription history will appear here.")
                )
            } else {
                List {
                    ForEach(appState.transcriptionHistory) { record in
                        TranscriptionRow(record: record)
                    }
                }
            }
        }
    }
}

struct TranscriptionRow: View {
    let record: TranscriptionRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.displayText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            Text(record.displayText)
                .font(.body)
                .lineLimit(3)

            if let corrected = record.correctedText, corrected != record.originalText {
                Text("Original: \(record.originalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
