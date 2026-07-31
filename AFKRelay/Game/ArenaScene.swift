import SpriteKit

/// SpriteKit owns render cadence only. The fixed-step handler advances the
/// framework-free simulation and returns an immutable presentation snapshot.
@MainActor
final class ArenaScene: SKScene {
    typealias FixedStepHandler = @MainActor (TimeInterval) -> ArenaRenderSnapshot?

    static let fixedStepDuration: TimeInterval = 1.0 / 60.0
    static let maximumCatchUpSteps = 15

    var fixedStepHandler: FixedStepHandler?
    var diagnosticsOptions = DiagnosticsOptions.disabled
    var accessibilityOptions = ArenaAccessibilityOptions.standard
    private(set) var renderedFramesPerSecond = 0

    private let renderer: ArenaRenderer
    private var latestSnapshot: ArenaRenderSnapshot?
    private var previousRenderTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    private var frameMeasurementDuration: TimeInterval = 0
    private var measuredFrameCount = 0
    private var applicationIsActive = true

    init(catalog: any ArenaPresentationCatalog = DiagnosticCatalog()) {
        renderer = ArenaRenderer(catalog: catalog)
        super.init(size: CGSize(width: 390, height: 844))
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        renderer = ArenaRenderer()
        super.init(coder: aDecoder)
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    override func didMove(to view: SKView) {
        renderer.attach(to: self)
        renderer.setViewportSize(size)
        view.preferredFramesPerSecond = 60
        view.shouldCullNonVisibleNodes = true
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        renderer.setViewportSize(size)
    }

    override func update(_ currentTime: TimeInterval) {
        guard applicationIsActive else {
            previousRenderTime = nil
            return
        }

        guard let previousRenderTime else {
            self.previousRenderTime = currentTime
            renderLatestSnapshot()
            return
        }

        let renderDelta = min(max(currentTime - previousRenderTime, 0), 0.25)
        self.previousRenderTime = currentTime
        accumulatedTime += renderDelta
        frameMeasurementDuration += renderDelta
        measuredFrameCount += 1
        if frameMeasurementDuration >= 0.5 {
            renderedFramesPerSecond = Int(
                (Double(measuredFrameCount) / frameMeasurementDuration).rounded()
            )
            frameMeasurementDuration = 0
            measuredFrameCount = 0
        }

        var advancedSteps = 0
        while accumulatedTime >= Self.fixedStepDuration,
              advancedSteps < Self.maximumCatchUpSteps
        {
            if let snapshot = fixedStepHandler?(Self.fixedStepDuration) {
                latestSnapshot = snapshot
            }
            accumulatedTime -= Self.fixedStepDuration
            advancedSteps += 1
        }

        if advancedSteps == Self.maximumCatchUpSteps {
            accumulatedTime = min(accumulatedTime, Self.fixedStepDuration)
        }

        renderLatestSnapshot()
    }

    func publish(_ snapshot: ArenaRenderSnapshot) {
        latestSnapshot = snapshot
        renderLatestSnapshot()
    }

    func setApplicationActive(_ isActive: Bool) {
        applicationIsActive = isActive
        previousRenderTime = nil
        accumulatedTime = 0
        frameMeasurementDuration = 0
        measuredFrameCount = 0
        isPaused = !isActive
    }

    private func renderLatestSnapshot() {
        guard let latestSnapshot else { return }
        renderer.render(
            latestSnapshot,
            diagnostics: diagnosticsOptions,
            accessibility: accessibilityOptions
        )
    }
}
