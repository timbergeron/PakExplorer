import SwiftUI

struct PreferencesView: View {
    @AppStorage(FinderPreferencesKey.actionsEnabled) private var actionsEnabled: Bool = true
    @AppStorage(FinderPreferencesKey.nestActions) private var nestActions: Bool = false
    @AppStorage(FinderPreferencesKey.showIcons) private var showIcons: Bool = true

    var body: some View {
        Form {
            Toggle("Show PakScape actions in Finder's contextual menu", isOn: $actionsEnabled)
                .onChange(of: actionsEnabled) { _, newValue in
                    FinderServiceManager.shared.updateRegistration(isEnabled: newValue)
                }

            Toggle("Nest actions in a submenu", isOn: $nestActions)
                .disabled(!actionsEnabled)

            Toggle("Show icons in actions", isOn: $showIcons)
                .disabled(!actionsEnabled)

            Text("Changes may require reopening Finder menus for the updates to appear.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .frame(minWidth: 420)
    }
}
