import SwiftUI

@main
struct XiaoZhuShouApp: App {
    @StateObject private var store = ConfigStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
                .onOpenURL { url in
                    // xiaozhushou://open?url=http://100.64.0.12:8000
                    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
                          let target = comps.queryItems?.first(where: { $0.name == "url" })?.value,
                          !target.isEmpty
                    else { return }
                    store.target = target
                    store.autoConnect = true
                }
        }
    }
}
