import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SettingsScreen: View {
    let runtime: CoreRuntimeActor?
    @AppStorage("reader.appearance") private var appearance = ReaderAppearance.system
    @AppStorage("reader.shelf.sort") private var shelfSort = ShelfSort.added
    @AppStorage("reader.keepAwake") private var keepAwake = false
    @AppStorage("reader.paper") private var paper = ReaderPaper.all[0].id

    var body: some View {
        Form {
            Section {
                Toggle("阅读时保持屏幕常亮", isOn: $keepAwake)
            } header: {
                Label {
                    Text("通用")
                } icon: {
                    ReaderIcon(ReaderIconRegistry.settingsNavigation).frame(width: 18, height: 18)
                }
            }
            Section("书架") {
                Picker("排序", selection: $shelfSort) {
                    ForEach(ShelfSort.allCases, id: \.self) { Text($0.label).tag($0) }
                }
            }
            Section("外观") {
                Picker("应用外观", selection: $appearance) {
                    ForEach(ReaderAppearance.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("默认阅读纸底", selection: $paper) {
                    ForEach(ReaderPaper.all, id: \.id) { Text($0.name).tag($0.id) }
                }
            }
            if let runtime {
                Section("朗读") {
                    NavigationLink {
                        SpeechConfigurationScreen(configuration: SpeechConfiguration(runtime: runtime))
                    } label: {
                        Label {
                            Text("朗读引擎与音色")
                        } icon: {
                            ReaderIcon(ReaderIconRegistry.ttsHeadphones, squareSize: 18)
                        }
                    }
                    .accessibilityIdentifier("reader-settings-tts")
                }
            }
        }
        .navigationTitle("设置")
    }
}
