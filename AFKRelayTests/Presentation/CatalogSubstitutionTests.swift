import SpriteKit
import Testing
import UIKit
@testable import AFKRelay

@Suite("Presentation catalog substitution")
@MainActor
struct CatalogSubstitutionTests {
    @Test("Diagnostic sound roles resolve unique bundled resources")
    func diagnosticSoundsAreBundled() throws {
        let catalog = DiagnosticCatalog()
        var fileNames: Set<String> = []

        for role in PresentationSoundRole.allCases {
            let fileName = try #require(catalog.soundFileName(for: role))
            #expect(fileNames.insert(fileName).inserted)
            #expect(
                Bundle.main.url(
                    forResource: fileName,
                    withExtension: nil
                ) != nil
            )
        }
    }

    @Test("Two catalogs change resources but never mechanics or results")
    func catalogInvariance() {
        let cyan = TinyTestCatalog(
            identifier: "tiny-cyan",
            color: .cyan,
            shapeInset: 2
        )
        let magenta = TinyTestCatalog(
            identifier: "tiny-magenta",
            color: .magenta,
            shapeInset: 8
        )
        var firstSimulation = ArenaSimulation(tutorialCompleted: true)
        var secondSimulation = firstSimulation
        var firstEconomy = EconomyState(
            eligibilityStart: .distantPast,
            lifetimeStepsCredited: 10_000
        )
        var secondEconomy = firstEconomy
        var firstEvents: [GameEvent] = []
        var secondEvents: [GameEvent] = []

        for tick in 0..<1_200 {
            if firstSimulation.result != nil || secondSimulation.result != nil {
                break
            }
            let phase = Double(tick) / 90
            let input = tick < 480
                ? Vector2(x: cos(phase), y: sin(phase))
                : .zero
            let firstTickEvents = firstSimulation.step(input: input)
            let secondTickEvents = secondSimulation.step(input: input)
            firstEvents += firstTickEvents
            secondEvents += secondTickEvents

            let firstSpendBefore = firstEconomy.lifetimeTokensSpent
            let secondSpendBefore = secondEconomy.lifetimeTokensSpent
            _ = MovementCostPolicy.commit(
                distance: firstSimulation.lastPlayerTravelDistance,
                state: &firstEconomy
            )
            _ = MovementCostPolicy.commit(
                distance: secondSimulation.lastPlayerTravelDistance,
                state: &secondEconomy
            )
            firstSimulation.recordMovementTokensSpent(
                firstEconomy.lifetimeTokensSpent - firstSpendBefore
            )
            secondSimulation.recordMovementTokensSpent(
                secondEconomy.lifetimeTokensSpent - secondSpendBefore
            )
        }

        let firstPresentation = ArenaSnapshotPresentationAdapter.makeSnapshot(
            from: firstSimulation.snapshot,
            events: Array(firstEvents.suffix(8))
        )
        let secondPresentation = ArenaSnapshotPresentationAdapter.makeSnapshot(
            from: secondSimulation.snapshot,
            events: Array(secondEvents.suffix(8))
        )

        #expect(cyan.catalogIdentifier != magenta.catalogIdentifier)
        #expect(
            cyan.style(for: .playerBody, accessibility: .standard).fillColor
                != magenta.style(
                    for: .playerBody,
                    accessibility: .standard
                ).fillColor
        )
        #expect(
            cyan.entityTexture(
                for: .playerBody,
                accessibility: .standard
            ) !== magenta.entityTexture(
                for: .playerBody,
                accessibility: .standard
            )
        )
        #expect(
            cyan.soundFileName(for: .friendlyFireImpact)
                != magenta.soundFileName(for: .friendlyFireImpact)
        )
        #expect(firstSimulation.snapshot == secondSimulation.snapshot)
        #expect(firstEvents == secondEvents)
        #expect(firstEconomy == secondEconomy)
        #expect(firstSimulation.result == secondSimulation.result)
        #expect(firstPresentation == secondPresentation)
    }
}

@MainActor
private final class TinyTestCatalog: ArenaPresentationCatalog {
    let catalogIdentifier: String
    private let color: SKColor
    private let texture: SKTexture

    init(identifier: String, color: SKColor, shapeInset: CGFloat) {
        catalogIdentifier = identifier
        self.color = color
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 32, height: 32)
        )
        let image = renderer.image { context in
            color.setFill()
            context.cgContext.fill(
                CGRect(
                    x: shapeInset,
                    y: shapeInset,
                    width: 32 - shapeInset * 2,
                    height: 32 - shapeInset * 2
                )
            )
        }
        texture = SKTexture(image: image)
    }

    func style(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> PresentationStyle {
        PresentationStyle(
            fillColor: color,
            strokeColor: .white,
            lineWidth: accessibility.increaseContrast ? 6 : 3,
            fillAlpha: role == .arenaBoundary ? 0 : 1
        )
    }

    func entityTexture(
        for role: PresentationRole,
        accessibility: ArenaAccessibilityOptions
    ) -> SKTexture {
        texture
    }

    func soundFileName(for role: PresentationSoundRole) -> String? {
        "\(catalogIdentifier)-\(role.rawValue).wav"
    }
}
