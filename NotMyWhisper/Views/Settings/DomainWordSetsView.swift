import SwiftUI

struct DomainWordSetsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newWordText: [UUID: String] = [:]

    var body: some View {
        Form {
            Section {
                Text("도메인별 단어 세트를 활성화하면 음성 인식 시 해당 단어들이 더 정확하게 인식됩니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("단어 세트") {
                if appState.settings.domainWordSets.isEmpty {
                    Text("등록된 단어 세트가 없습니다. 아래에서 기본 세트를 추가하세요.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(appState.settings.domainWordSets.indices, id: \.self) { index in
                        WordSetRow(
                            wordSet: $appState.settings.domainWordSets[index],
                            newWordText: Binding(
                                get: { newWordText[appState.settings.domainWordSets[index].id] ?? "" },
                                set: { newWordText[appState.settings.domainWordSets[index].id] = $0 }
                            ),
                            onAddWord: { addWord(at: index) },
                            onDeleteWord: { wordIndex in deleteWord(at: wordIndex, setIndex: index) },
                            onToggle: { save() }
                        )
                    }
                    .onDelete { offsets in
                        appState.settings.domainWordSets.remove(atOffsets: offsets)
                        save()
                    }
                }
            }

            Section("기본 세트 추가") {
                ForEach(DomainCategory.allCases, id: \.self) { category in
                    let alreadyAdded = appState.settings.domainWordSets.contains {
                        $0.name == DomainWordSet.generateDefault(domain: category).name
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.rawValue)
                                .font(.body)
                            Text(categoryDescription(for: category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if alreadyAdded {
                            Label("추가됨", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.green)
                        } else {
                            Button("추가") {
                                let newSet = DomainWordSet.generateDefault(domain: category)
                                appState.settings.domainWordSets.append(newSet)
                                save()
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func addWord(at index: Int) {
        let id = appState.settings.domainWordSets[index].id
        let word = (newWordText[id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }
        appState.settings.domainWordSets[index].words.append(word)
        newWordText[id] = ""
        save()
    }

    private func deleteWord(at wordIndex: Int, setIndex: Int) {
        appState.settings.domainWordSets[setIndex].words.remove(at: wordIndex)
        save()
    }

    private func save() {
        appState.settings.save()
    }

    private func categoryDescription(for category: DomainCategory) -> String {
        switch category {
        case .itDev: return "API, React, Docker, LLM 등 개발 용어 30개"
        case .statistics: return "T-distribution, p-value, ANOVA 등 통계 용어 24개"
        case .custom: return "직접 단어를 추가할 수 있는 빈 세트"
        }
    }
}

private struct WordSetRow: View {
    @Binding var wordSet: DomainWordSet
    @Binding var newWordText: String
    let onAddWord: () -> Void
    let onDeleteWord: (Int) -> Void
    let onToggle: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Toggle(isOn: Binding(
                    get: { wordSet.isEnabled },
                    set: { wordSet.isEnabled = $0; onToggle() }
                )) {
                    EmptyView()
                }
                .toggleStyle(.switch)
                .labelsHidden()

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(wordSet.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("\(wordSet.words.count)개 단어")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 4)

            if isExpanded {
                Divider()
                    .padding(.vertical, 6)

                if wordSet.words.isEmpty {
                    Text("단어가 없습니다.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.bottom, 6)
                } else {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(wordSet.words.indices, id: \.self) { wordIndex in
                            HStack(spacing: 6) {
                                TextField("단어", text: Binding(
                                    get: { wordSet.words[wordIndex] },
                                    set: { wordSet.words[wordIndex] = $0 }
                                ))
                                .textFieldStyle(.plain)
                                .font(.system(.body, design: .monospaced))

                                Button(action: { onDeleteWord(wordIndex) }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 2)

                            if wordIndex < wordSet.words.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.bottom, 6)
                }

                HStack(spacing: 8) {
                    TextField("새 단어 추가", text: $newWordText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { onAddWord() }

                    Button(action: onAddWord) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newWordText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(.bottom, 4)
            }
        }
    }
}
