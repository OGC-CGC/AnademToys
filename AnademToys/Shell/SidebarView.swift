import SwiftUI

struct SidebarView: View {
    @Binding var selectedModule: FeatureModule

    var body: some View {
        List(selection: $selectedModule) {
            Section("功能") {
                ForEach([FeatureModule.urlSchemes, .archives]) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            }

            Section("应用") {
                ForEach([FeatureModule.generalSettings, .about]) { module in
                    Label(module.title, systemImage: module.systemImage)
                        .tag(module)
                }
            }
        }
        .navigationTitle("AnademToys")
        .listStyle(.sidebar)
    }
}
