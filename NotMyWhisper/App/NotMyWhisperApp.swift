import SwiftUI

@main
struct NotMyWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // Settings window는 AppDelegate.showSettings()에서 관리
            // (hotkeyManager, modelManager 등이 setupServices() 이후에 초기화되므로
            //  SwiftUI Scene에서 직접 참조하면 앱 시작 시 크래시)
            Text("설정은 메뉴바 아이콘에서 열 수 있습니다.")
                .padding(40)
        }
    }
}
