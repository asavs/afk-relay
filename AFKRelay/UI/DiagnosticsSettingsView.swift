import SwiftUI

struct DiagnosticsSettingsView: View {
    @Binding var options: DiagnosticsOptions

    var body: some View {
        Section {
            Toggle("Enable inspection", isOn: $options.isEnabled)

            Group {
                Toggle("Entity identifiers", isOn: $options.showsEntityIdentifiers)
                Toggle("Attack identifiers", isOn: $options.showsAttackIdentifiers)
                Toggle("Intended paths", isOn: $options.showsIntentPaths)
                Toggle("Resolved paths", isOn: $options.showsResolvedPaths)
                Toggle("Collision normals", isOn: $options.showsCollisionNormals)
                Toggle("Pursuit vectors", isOn: $options.showsPursuitVectors)
                Toggle("Phase timing", isOn: $options.showsPhaseTiming)
                Toggle("Frame metrics", isOn: $options.showsFrameMetrics)
            }
            .disabled(!options.isEnabled)
        } header: {
            Text("Inspection overlay")
        } footer: {
            Text("The overlay only reveals simulation state. It never changes movement, collisions, attacks, or the step economy.")
        }
    }
}
