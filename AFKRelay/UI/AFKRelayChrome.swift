import SwiftUI

/// Chrome that adapts to the running iOS rather than to the build.
///
/// The tempting simplification here is to delete this file and use the
/// semantic styles — `.bordered` and `.borderedProminent` — on the theory
/// that each iOS renders them in its own idiom. It was tried and it is
/// wrong: on iOS 26 those styles adopt the capsule shape but *not* the
/// Liquid Glass material. Rendered beside `.glass` in the same view, a
/// bordered button is flat and sinks into the panel behind it while the
/// glass one carries a specular rim and floats. Only the explicit glass
/// styles produce the material.
///
/// The explicit styles cost something in return: `.glass` discards `tint`,
/// so a destructive action cannot be coloured through it. `.glassProminent`
/// honours the tint but fills solid, which trades the material away again.
/// Destructive actions therefore take plain glass with a coloured label —
/// the material survives and the warning still reads.
///
/// Increased-contrast handling stays with each surface: contrast wins over
/// every branch here, and those solid fills already existed.
enum AFKRelayChrome {
    /// Renders the pre-26 chrome on a newer OS so the fallback can be
    /// reviewed without an old simulator runtime installed.
    static let forcesLegacyChrome = ProcessInfo.processInfo
        .environment["AFKRelayForceLegacyChrome"] == "1"
}

extension View {
    /// Glass on iOS 26 and later, a system material below it.
    func afkChromeBackground(in shape: some Shape) -> some View {
        modifier(AFKChromeBackground(shape: shape))
    }

    /// Liquid Glass on iOS 26 and later, bordered fills below it.
    ///
    /// `destructiveTint` colours the label on the glass path, where the
    /// style would otherwise drop it. Below 26 the bordered styles honour
    /// an ordinary `tint` at the call site, so nothing is passed here.
    func afkChromeButtonStyle(
        prominent: Bool = false,
        destructiveTint: Color? = nil
    ) -> some View {
        modifier(
            AFKChromeButtonStyle(
                isProminent: prominent,
                destructiveTint: destructiveTint
            )
        )
    }
}

private struct AFKChromeBackground<ChromeShape: Shape>: ViewModifier {
    let shape: ChromeShape

    func body(content: Content) -> some View {
        if #available(iOS 26, *), !AFKRelayChrome.forcesLegacyChrome {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.regularMaterial, in: shape)
        }
    }
}

private struct AFKChromeButtonStyle: ViewModifier {
    let isProminent: Bool
    let destructiveTint: Color?

    func body(content: Content) -> some View {
        if #available(iOS 26, *), !AFKRelayChrome.forcesLegacyChrome {
            if let destructiveTint {
                content.buttonStyle(.glass).foregroundStyle(destructiveTint)
            } else if isProminent {
                content.buttonStyle(.glassProminent)
            } else {
                content.buttonStyle(.glass)
            }
        } else {
            if isProminent {
                content.buttonStyle(.borderedProminent)
            } else {
                content.buttonStyle(.bordered)
            }
        }
    }
}
