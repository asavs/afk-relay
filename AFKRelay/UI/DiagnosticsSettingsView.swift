import SwiftUI

struct DiagnosticsSettingsView: View {
    @Binding var options: DiagnosticsOptions

    var body: some View {
        Section {
            Toggle("Enable Inspection", isOn: $options.isEnabled)

            Group {
                Toggle("Entity Identifiers", isOn: $options.showsEntityIdentifiers)
                Toggle("Attack Identifiers", isOn: $options.showsAttackIdentifiers)
                Toggle("Intended Paths", isOn: $options.showsIntentPaths)
                Toggle("Resolved Paths", isOn: $options.showsResolvedPaths)
                Toggle("Collision Normals", isOn: $options.showsCollisionNormals)
                Toggle("Pursuit Vectors", isOn: $options.showsPursuitVectors)
                Toggle("Phase Timing", isOn: $options.showsPhaseTiming)
                Toggle("Frame Metrics", isOn: $options.showsFrameMetrics)
            }
            .disabled(!options.isEnabled)
        } header: {
            Text("Developer")
        } footer: {
            Text("Shows what the game is doing under the hood. It never changes gameplay or your movement bank.")
        }
    }
}
