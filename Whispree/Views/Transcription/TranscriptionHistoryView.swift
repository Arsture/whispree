import SwiftUI

struct TranscriptionHistoryView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("기록")
                    .font(.title2.bold())
                Spacer()
                if !appState.transcriptionHistory.isEmpty {
                    Button("Clear All") {
                        appState.transcriptionHistory.removeAll()
                    }
                    .font(.caption)
                }
            }
            .padding(24)

            Divider()

            // Content
            if appState.transcriptionHistory.isEmpty {
                Spacer()
                ContentUnavailableView(
                    "No Transcriptions Yet",
                    systemImage: "text.bubble",
                    description: Text("Your transcription history will appear here.")
                )
                Spacer()
            } else {
                List {
                    ForEach(appState.transcriptionHistory) { record in
                        TranscriptionRow(record: record)
                            .listRowInsets(EdgeInsets(top: 8, leading: 24, bottom: 8, trailing: 24))
                    }
                }
                .listStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct TranscriptionRow: View {
    let record: TranscriptionRecord
    @State private var isDisplayTextExpanded = false
    @State private var isOriginalExpanded = false

    private var hasCorrectedText: Bool {
        if let corrected = record.correctedText, corrected != record.originalText {
            return true
        }
        return false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                if hasCorrectedText {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(record.originalText, forType: .string)
                    } label: {
                        HStack(spacing: 2) {
                            Image(systemName: "doc.on.doc")
                            Text("원본")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .help("원본 텍스트 복사")
                }
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.displayText, forType: .string)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.on.doc")
                        if hasCorrectedText {
                            Text("교정")
                        }
                    }
                    .font(.caption)
                }
                .buttonStyle(.plain)
                .help(hasCorrectedText ? "교정된 텍스트 복사" : "텍스트 복사")
            }

            Text(record.displayText)
                .font(.body)
                .lineLimit(isDisplayTextExpanded ? nil : 3)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isDisplayTextExpanded.toggle()
                    }
                }
                .contentShape(Rectangle())

            if hasCorrectedText {
                Text("Original: \(record.originalText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(isOriginalExpanded ? nil : 1)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isOriginalExpanded.toggle()
                        }
                    }
                    .contentShape(Rectangle())
            }
        }
        .padding(.vertical, 4)
    }
}
