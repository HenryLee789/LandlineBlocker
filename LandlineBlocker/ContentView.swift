import SwiftUI

struct ContentView: View {
    @AppStorage("appearanceMode") private var appearanceModeRaw = AppAppearanceMode.system.rawValue
    @StateObject private var viewModel = BlacklistViewModel()
    @State private var selectedTab = AppTab.dashboard
    @State private var blacklistSearchText = ""

    private var appearanceMode: AppAppearanceMode {
        AppAppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var appearanceModeBinding: Binding<AppAppearanceMode> {
        Binding(
            get: { appearanceMode },
            set: { appearanceModeRaw = $0.rawValue }
        )
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(
                viewModel: viewModel,
                openImport: openImport,
                openBlacklist: openBlacklist
            )
            .tabItem {
                Label("首页", systemImage: "shield.lefthalf.filled")
            }
            .tag(AppTab.dashboard)

            ImportNumbersView(viewModel: viewModel)
                .tabItem {
                    Label("导入", systemImage: "square.and.arrow.down")
                }
                .tag(AppTab.importNumbers)

            BlacklistManagementView(
                viewModel: viewModel,
                searchText: $blacklistSearchText
            )
            .tabItem {
                Label("黑名单", systemImage: "phone.down")
            }
            .tag(AppTab.blacklist)

            SettingsView(
                viewModel: viewModel,
                appearanceMode: appearanceModeBinding
            )
            .tabItem {
                Label("设置", systemImage: "slider.horizontal.3")
            }
            .tag(AppTab.settings)
        }
        .tint(.teal)
        .preferredColorScheme(appearanceMode.colorScheme)
        .overlay {
            if viewModel.isProcessing {
                ProcessingOverlay()
            }
        }
        .sheet(item: $viewModel.exportFile) { file in
            ActivityView(activityItems: [file.url])
        }
        .task {
            await viewModel.loadInitialData()
            await viewModel.refreshExtensionStatus()
        }
    }

    private func openImport() {
        selectedTab = .importNumbers
    }

    private func openBlacklist() {
        selectedTab = .blacklist
    }
}

private enum AppTab: Hashable {
    case dashboard
    case importNumbers
    case blacklist
    case settings
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
