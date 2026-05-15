import SwiftUI

// MARK: - SettingsView

struct SettingsView: View {

    @AppStorage("theme") private var theme = "system"
    @AppStorage("language") private var language = "en"

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                appearanceSection
                languageSection
            }
            .navigationTitle(L10n.settings)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.close) { dismiss() }
                }
            }
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section(L10n.appearance) {
            Picker(L10n.appearance, selection: $theme) {
                Text(L10n.light).tag("light")
                Text(L10n.dark).tag("dark")
                Text(L10n.system).tag("system")
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Language

    private var languageSection: some View {
        Section(L10n.language) {
            Picker(L10n.language, selection: $language) {
                Text(L10n.englishLabel).tag("en")
                Text(L10n.chineseLabel).tag("zh-Hans")
            }
            .pickerStyle(.segmented)
        }
    }
}

#Preview {
    SettingsView()
}
