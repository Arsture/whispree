import SwiftUI

struct DomainWordSetsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newWordText: [UUID: String] = [:]
    @State private var newCorrectionFrom: [UUID: String] = [:]
    @State private var newCorrectionTo: [UUID: String] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                guidanceCard

                if appState.settings.domainWordSets.isEmpty {
                    emptyStateCard
                } else {
                    ForEach(appState.settings.domainWordSets.indices, id: \.self) { index in
                        WordSetRow(
                            wordSet: Binding(
                                get: { appState.settings.domainWordSets[index] },
                                set: { newValue in
                                    var sets = appState.settings.domainWordSets
                                    sets[index] = newValue
                                    appState.settings.domainWordSets = sets
                                }
                            ),
                            newWordText: Binding(
                                get: { newWordText[appState.settings.domainWordSets[index].id] ?? "" },
                                set: { newWordText[appState.settings.domainWordSets[index].id] = $0 }
                            ),
                            newCorrectionFrom: Binding(
                                get: { newCorrectionFrom[appState.settings.domainWordSets[index].id] ?? "" },
                                set: { newCorrectionFrom[appState.settings.domainWordSets[index].id] = $0 }
                            ),
                            newCorrectionTo: Binding(
                                get: { newCorrectionTo[appState.settings.domainWordSets[index].id] ?? "" },
                                set: { newCorrectionTo[appState.settings.domainWordSets[index].id] = $0 }
                            ),
                            onAddWord: { addWord(at: index) },
                            onDeleteWord: { wordIndex in deleteWord(at: wordIndex, setIndex: index) },
                            onAddCorrection: { addCorrection(at: index) },
                            onDeleteCorrection: { corrIndex in deleteCorrection(at: corrIndex, setIndex: index) },
                            onToggle: {}
                        )
                        .padding(20)
                        .background(DesignTokens.surfaceBackgroundView(role: .editor, cornerRadius: DesignTokens.Radius.xxl))
                    }
                }

                defaultSetsCard
            }
            .padding(24)
        }
        .background {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.white.opacity(0.04),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var guidanceCard: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(DesignTokens.interactionColors(for: .selection).background)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Circle()
                            .stroke(DesignTokens.interactionColors(for: .selection).border, lineWidth: 1)
                    }
                Image(systemName: "textformat.abc.dottedunderline")
                    .foregroundStyle(DesignTokens.accentPrimary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("도메인 단어 세트")
                    .font(.headline)
                Text("도메인별 단어 세트를 활성화하면 음성 인식과 교정 단계에서 해당 단어들이 더 정확하게 처리됩니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(DesignTokens.surfaceBackgroundView(role: .editor, cornerRadius: DesignTokens.Radius.xxl))
    }

    private var emptyStateCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
            Text("등록된 단어 세트가 없습니다")
                .font(.headline)
            Text("아래에서 기본 세트를 추가하거나 직접 세트를 만들어서 용어와 교정 매핑을 관리하세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(DesignTokens.surfaceBackgroundView(role: .card, cornerRadius: DesignTokens.Radius.xxl))
    }

    private var defaultSetsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("기본 세트 추가")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(DomainCategory.allCases, id: \.self) { category in
                    let alreadyAdded = appState.settings.domainWordSets.contains {
                        $0.name == DomainWordSet.generateDefault(domain: category).name
                    }

                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(category.rawValue)
                                .font(.body.weight(.semibold))
                            Text(categoryDescription(for: category))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if alreadyAdded {
                            StatusBadge("추가됨", icon: "checkmark", style: .neutral)
                        } else {
                            Button("추가") {
                                var sets = appState.settings.domainWordSets
                                sets.append(DomainWordSet.generateDefault(domain: category))
                                appState.settings.domainWordSets = sets
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(14)
                    .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 18))
                }
            }
        }
        .padding(20)
        .background(DesignTokens.surfaceBackgroundView(role: .card, cornerRadius: DesignTokens.Radius.xxl))
    }

    private func addWord(at index: Int) {
        let id = appState.settings.domainWordSets[index].id
        let word = (newWordText[id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !word.isEmpty else { return }
        var sets = appState.settings.domainWordSets
        sets[index].words.append(word)
        appState.settings.domainWordSets = sets
        newWordText[id] = ""
    }

    private func deleteWord(at wordIndex: Int, setIndex: Int) {
        var sets = appState.settings.domainWordSets
        sets[setIndex].words.remove(at: wordIndex)
        appState.settings.domainWordSets = sets
    }

    private func addCorrection(at index: Int) {
        let id = appState.settings.domainWordSets[index].id
        let from = (newCorrectionFrom[id] ?? "").trimmingCharacters(in: .whitespaces)
        let to = (newCorrectionTo[id] ?? "").trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return }
        var sets = appState.settings.domainWordSets
        sets[index].corrections.append(CorrectionMapping(from: from, to: to))
        appState.settings.domainWordSets = sets
        newCorrectionFrom[id] = ""
        newCorrectionTo[id] = ""
    }

    private func deleteCorrection(at corrIndex: Int, setIndex: Int) {
        var sets = appState.settings.domainWordSets
        sets[setIndex].corrections.remove(at: corrIndex)
        appState.settings.domainWordSets = sets
    }

    private func categoryDescription(for category: DomainCategory) -> String {
        switch category {
            case .itDev: "API, React, Docker, LLM 등 개발 용어 30개"
            case .statistics: "T-distribution, p-value, ANOVA 등 통계 용어 24개"
            case .custom: "직접 단어를 추가할 수 있는 빈 세트"
        }
    }
}

private struct WordSetRow: View {
    @Binding var wordSet: DomainWordSet
    @Binding var newWordText: String
    @Binding var newCorrectionFrom: String
    @Binding var newCorrectionTo: String
    let onAddWord: () -> Void
    let onDeleteWord: (Int) -> Void
    let onAddCorrection: () -> Void
    let onDeleteCorrection: (Int) -> Void
    let onToggle: () -> Void

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if isExpanded {
                VStack(spacing: 14) {
                    contentSection(
                        title: "단어",
                        subtitle: "STT + LLM",
                        accent: .secondary
                    ) {
                        if wordSet.words.isEmpty {
                            emptyLine("단어가 없습니다.")
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(wordSet.words.indices, id: \.self) { wordIndex in
                                    HStack(spacing: 10) {
                                        TextField("단어", text: Binding(
                                            get: { wordSet.words[wordIndex] },
                                            set: { wordSet.words[wordIndex] = $0 }
                                        ))
                                        .textFieldStyle(.plain)
                                        .font(.system(.body, design: .monospaced))

                                        Button(action: { onDeleteWord(wordIndex) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 16))
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            TextField("새 단어 추가", text: $newWordText)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { onAddWord() }

                            Button(action: onAddWord) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(DesignTokens.accentPrimary)
                            }
                            .buttonStyle(.plain)
                            .disabled(newWordText.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 16))
                    }

                    contentSection(
                        title: "교정 매핑",
                        subtitle: "LLM only",
                        accent: DesignTokens.semanticColors(for: .warning).foreground
                    ) {
                        if wordSet.corrections.isEmpty {
                            emptyLine("교정 매핑이 없습니다.")
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(wordSet.corrections.indices, id: \.self) { corrIndex in
                                    HStack(spacing: 10) {
                                        Text(wordSet.corrections[corrIndex].from)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(DesignTokens.textColor(for: .secondary))
                                        Image(systemName: "arrow.right")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(wordSet.corrections[corrIndex].to)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(DesignTokens.textColor(for: .primary))
                                        Spacer()
                                        Button(action: { onDeleteCorrection(corrIndex) }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundStyle(DesignTokens.semanticColors(for: .danger).foreground.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 16))
                                }
                            }
                        }

                        HStack(spacing: 6) {
                            TextField("잘못된 표현", text: $newCorrectionFrom)
                                .textFieldStyle(.roundedBorder)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("올바른 단어", text: $newCorrectionTo)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { onAddCorrection() }
                            Button(action: onAddCorrection) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(DesignTokens.accentPrimary)
                            }
                            .buttonStyle(.plain)
                            .disabled(
                                newCorrectionFrom.trimmingCharacters(in: .whitespaces).isEmpty ||
                                    newCorrectionTo.trimmingCharacters(in: .whitespaces).isEmpty
                            )
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 16))
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { wordSet.isEnabled },
                set: {
                    wordSet.isEnabled = $0
                    onToggle()
                }
            )) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 6) {
                Text(wordSet.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    statPill("\(wordSet.words.count)개 단어")
                    if !wordSet.corrections.isEmpty {
                        statPill("\(wordSet.corrections.count)개 매핑", accent: DesignTokens.semanticColors(for: .warning).foreground)
                    }
                }
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(DesignTokens.surfaceBackgroundView(role: .card, cornerRadius: 22))
    }

    private func contentSection<Content: View>(
        title: String,
        subtitle: String,
        accent: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(accent)
                Spacer()
            }

            content()
        }
        .padding(16)
        .background(DesignTokens.surfaceBackgroundView(role: .card, cornerRadius: 22))
    }

    private func emptyLine(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 16))
    }

    private func statPill(_ text: String, accent: Color = DesignTokens.textColor(for: .secondary)) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(DesignTokens.surfaceBackgroundView(role: .inset, cornerRadius: 14))
    }
}
