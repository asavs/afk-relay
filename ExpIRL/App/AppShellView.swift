import SpriteKit
import SwiftUI

struct AppShellView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var arenaScene = ArenaScene()

    var body: some View {
        SpriteView(
            scene: arenaScene,
            options: [.ignoresSiblingOrder],
            debugOptions: debugOptions
        )
        .ignoresSafeArea()
        .accessibilityIdentifier("arena")
        .onChange(of: scenePhase) { _, newPhase in
            arenaScene.setApplicationActive(newPhase == .active)
        }
    }

    private var debugOptions: SpriteView.DebugOptions {
#if DEBUG
        [.showsFPS, .showsNodeCount]
#else
        []
#endif
    }
}
