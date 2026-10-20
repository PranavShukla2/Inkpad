//
//  LaserPointer.swift
//  Inkpad
//

import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Tracks Pencil (or finger) touches for the laser pen.
final class LaserGestureRecognizer: UIGestureRecognizer {
    var onBegan: ((CGPoint) -> Void)?
    var onMoved: (([CGPoint]) -> Void)?
    var onEnded: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else {
            state = .failed
            return
        }
        onBegan?(touch.location(in: view))
        state = .began
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let touch = touches.first, let view else { return }
        // Coalesced touches keep the trail smooth at 120 Hz and above.
        let samples = event.coalescedTouches(for: touch) ?? [touch]
        onMoved?(samples.map { $0.location(in: view) })
        state = .changed
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        onEnded?()
        state = .ended
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        onEnded?()
        state = .cancelled
    }
}

/// Draws glowing laser trails. Everything written stays visible while you keep
/// writing, then the whole lot fades together once you pause.
/// Nothing here is ever added to the notebook.
final class LaserOverlayView: UIView {
    var color: UIColor = UIColor(hex: 0xFF3B30)
    /// How long a pause has to be before the trails fade.
    static let pauseBeforeFading: TimeInterval = 1.5

    private var points: [CGPoint] = []
    private var glowLayer: CAShapeLayer?
    private var coreLayer: CAShapeLayer?
    /// Finished trails still on screen, waiting for a pause.
    private var trails: [CAShapeLayer] = []
    private var fadeWork: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func begin(at point: CGPoint) {
        // Still writing: keep everything so far on screen.
        fadeWork?.cancel()
        points = [point]
        let glow = CAShapeLayer()
        glow.fillColor = nil
        glow.strokeColor = color.withAlphaComponent(0.35).cgColor
        glow.lineWidth = 12
        glow.lineCap = .round
        glow.lineJoin = .round
        glow.shadowColor = color.cgColor
        glow.shadowRadius = 8
        glow.shadowOpacity = 0.9
        glow.shadowOffset = .zero

        let core = CAShapeLayer()
        core.fillColor = nil
        core.strokeColor = UIColor.white.withAlphaComponent(0.95).cgColor
        core.lineWidth = 3
        core.lineCap = .round
        core.lineJoin = .round

        layer.addSublayer(glow)
        layer.addSublayer(core)
        glowLayer = glow
        coreLayer = core
        updatePath()
    }

    func add(_ newPoints: [CGPoint]) {
        points.append(contentsOf: newPoints)
        updatePath()
    }

    func end() {
        guard let glow = glowLayer, let core = coreLayer else { return }
        glowLayer = nil
        coreLayer = nil
        trails.append(contentsOf: [glow, core])

        let work = DispatchWorkItem { [weak self] in
            self?.fadeAllTrails()
        }
        fadeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.pauseBeforeFading, execute: work)
    }

    private func fadeAllTrails() {
        let fading = trails
        trails = []
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            fading.forEach { $0.removeFromSuperlayer() }
        }
        for trail in fading {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = 0.45
            fade.fillMode = .forwards
            fade.isRemovedOnCompletion = false
            trail.add(fade, forKey: "fade")
        }
        CATransaction.commit()
    }

    /// Smooths the trail with curves through the midpoints of the samples.
    private func updatePath() {
        guard let first = points.first else { return }
        let path = UIBezierPath()
        path.move(to: first)
        if points.count == 1 {
            path.addLine(to: first)
        }
        for index in 1..<max(points.count, 1) {
            let previous = points[index - 1]
            let current = points[index]
            let mid = CGPoint(x: (previous.x + current.x) / 2, y: (previous.y + current.y) / 2)
            path.addQuadCurve(to: mid, controlPoint: previous)
        }
        if let last = points.last {
            path.addLine(to: last)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        glowLayer?.path = path.cgPath
        coreLayer?.path = path.cgPath
        CATransaction.commit()
    }
}
