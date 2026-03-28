import SwiftUI

/// 스크린샷 선택 UI — 전사 완료 후 패널에서 표시
/// 키보드: ↑↓ 이동, Space 토글, Enter 확인/실행, Esc 건너뛰기, Cmd+Enter 미리보기
struct ScreenshotSelectionView: View {
    @EnvironmentObject var appState: AppState
    @State private var focusedIndex: Int = 0
    @State private var selectedIndices: Set<Int> = []
    /// 0 = 넘어가기, 1 = 모두 선택, 2+ = 이미지 인덱스 (i-2)
    private var totalItems: Int {
        2 + appState.capturedScreenshots.count
    }

    var body: some View {
        mainContent
            .onChange(of: appState.selectionKeyEvent) { _, event in
                guard let event else { return }
                handleKeyEvent(event)
                appState.selectionKeyEvent = nil
            }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.purple)
                Text("스크린샷 선택")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(selectedIndices.count)/\(appState.capturedScreenshots.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 6)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 2) {
                        // 넘어가기
                        actionRow(index: 0, icon: "arrow.right.circle", label: "넘어가기", color: .secondary)
                            .id(0)

                        // 모두 선택
                        actionRow(
                            index: 1,
                            icon: selectedIndices.count == appState.capturedScreenshots.count
                                ? "checkmark.circle.fill" : "circle.grid.2x2",
                            label: "모두 선택",
                            color: .blue
                        )
                        .id(1)

                        Divider().padding(.vertical, 2)

                        // 이미지 목록
                        ForEach(Array(appState.capturedScreenshots.enumerated()), id: \.element.id) { idx, screenshot in
                            imageRow(index: idx + 2, screenshot: screenshot, imageIndex: idx)
                                .id(idx + 2)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 320)
                .onChange(of: focusedIndex) { _, newIndex in
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            // Footer
            Divider()
            HStack(spacing: 8) {
                Spacer()
                keyHint("↑↓", "이동")
                keyHint("Space", "선택")
                keyHint("Enter", "확인")
                keyHint("⌘Enter", "미리보기")
                keyHint("Esc", "건너뛰기")
                Spacer()
            }
            .padding(.vertical, 6)
        }
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 3) {
            Text(key).font(.system(size: 9, design: .monospaced))
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(.quaternary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
    }

    // MARK: - Action Row

    private func actionRow(index: Int, icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 16)
            Text(label)
                .font(.caption)
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(focusedIndex == index ? Color.accentColor.opacity(0.15) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(focusedIndex == index ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focusedIndex = index
            handleEnter()
        }
    }

    // MARK: - Image Row

    private func imageRow(index: Int, screenshot: CapturedScreenshot, imageIndex: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: selectedIndices.contains(imageIndex) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(selectedIndices.contains(imageIndex) ? .blue : .secondary)
                .frame(width: 16)

            if let image = screenshot.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(screenshot.appName)
                    .font(.caption)
                    .lineLimit(1)
                Text(screenshot.timestamp.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(focusedIndex == index ? Color.accentColor.opacity(0.15) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(focusedIndex == index ? Color.accentColor.opacity(0.4) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            focusedIndex = index
            toggleImageSelection(imageIndex)
        }
    }

    // MARK: - Keyboard Handler

    private func handleKeyEvent(_ event: NSEvent) {
        let keyCode = event.keyCode
        let hasCmd = event.modifierFlags.contains(.command)

        switch keyCode {
        case 126: // ↑
            moveFocus(-1)
        case 125: // ↓
            moveFocus(1)
        case 49: // Space
            toggleSelection()
        case 36: // Enter
            if hasCmd {
                // Cmd+Enter → 미리보기
                showPreview()
            } else {
                handleEnter()
            }
        case 53: // Esc
            skip()
        default:
            break
        }
    }

    // MARK: - Actions

    private func moveFocus(_ delta: Int) {
        focusedIndex = max(0, min(totalItems - 1, focusedIndex + delta))
    }

    private func toggleSelection() {
        if focusedIndex == 0 {
            skip()
        } else if focusedIndex == 1 {
            toggleSelectAll()
        } else {
            toggleImageSelection(focusedIndex - 2)
        }
    }

    private func toggleImageSelection(_ imageIndex: Int) {
        if selectedIndices.contains(imageIndex) {
            selectedIndices.remove(imageIndex)
        } else {
            selectedIndices.insert(imageIndex)
        }
    }

    private func toggleSelectAll() {
        if selectedIndices.count == appState.capturedScreenshots.count {
            selectedIndices.removeAll()
        } else {
            selectedIndices = Set(0 ..< appState.capturedScreenshots.count)
        }
    }

    /// Enter 키 동작 — 포커스 위치에 따라 다르게 동작
    private func handleEnter() {
        if focusedIndex == 0 {
            // 넘어가기 → 스킵
            skip()
        } else if focusedIndex == 1 {
            // 모두 선택 → 전체 선택 + 확인
            selectedIndices = Set(0 ..< appState.capturedScreenshots.count)
            confirmSelection()
        } else {
            // 이미지 위에서 Enter → 선택된 것들 확인 (없으면 현재 이미지만)
            if selectedIndices.isEmpty {
                selectedIndices.insert(focusedIndex - 2)
            }
            confirmSelection()
        }
    }

    private func confirmSelection() {
        let selected = selectedIndices.sorted().compactMap { idx -> Data? in
            guard idx < appState.capturedScreenshots.count else { return nil }
            return appState.capturedScreenshots[idx].imageData
        }
        appState.screenshotSelectionCallback?(selected)
    }

    private func skip() {
        appState.screenshotSelectionCallback?([])
    }

    private func showPreview() {
        guard focusedIndex >= 2 else { return }
        let imageIndex = focusedIndex - 2
        guard imageIndex < appState.capturedScreenshots.count else { return }
        appState.previewRequestCallback?(appState.capturedScreenshots[imageIndex])
    }
}
