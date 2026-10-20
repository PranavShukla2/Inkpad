//
//  ProtractorView.swift
//  Inkpad
//

import UIKit

/// A protractor for measuring angles: drag it with one finger, twist it with
/// two, and swing its arm by the knob to read the angle. Lives in screen space
/// over the page, like the ruler.
final class ProtractorView: UIView, UIGestureRecognizerDelegate {
    private let radius: CGFloat = 210
    private let margin: CGFloat = 50

    private let body = UIView()
    private let scale = CAShapeLayer()
    private let arm = CAShapeLayer()
    private let knob = UIView()
    private let readout = UILabel()
    private var labels: [CATextLayer] = []

    private var protractorCenter: CGPoint = .zero
    private var rotation: CGFloat = 0
    /// The arm's angle from the baseline, in degrees (0–180).
    private var armDegrees: CGFloat = 45
    private var hasBeenPlaced = false
    private let haptics = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        let size = CGSize(width: (radius + margin) * 2, height: radius + margin * 2)
        body.bounds = CGRect(origin: .zero, size: size)
        // Pivot around the centre of the baseline.
        body.layer.anchorPoint = CGPoint(x: 0.5, y: (radius + margin) / size.height)

        let face = CAShapeLayer()
        face.path = UIBezierPath(arcCenter: pivot, radius: radius, startAngle: .pi, endAngle: 0, clockwise: true).cgPath
        face.fillColor = UIColor(hex: 0xF4EEE2, alpha: 0.88).cgColor
        face.strokeColor = UIColor(hex: 0xBFB3A0).cgColor
        face.lineWidth = 1
        face.shadowColor = UIColor.black.cgColor
        face.shadowOpacity = 0.16
        face.shadowRadius = 10
        face.shadowOffset = CGSize(width: 0, height: 4)
        body.layer.addSublayer(face)

        scale.strokeColor = UIColor(hex: 0x6E665B).cgColor
        scale.lineWidth = 1
        scale.path = scalePath().cgPath
        body.layer.addSublayer(scale)
        addLabels()

        arm.strokeColor = Palette.stamp.cgColor
        arm.lineWidth = 2
        arm.lineCap = .round
        body.layer.addSublayer(arm)

        knob.bounds = CGRect(x: 0, y: 0, width: 34, height: 34)
        knob.backgroundColor = Palette.stamp
        knob.layer.cornerRadius = 17
        knob.layer.borderColor = UIColor.white.cgColor
        knob.layer.borderWidth = 3
        knob.layer.shadowOpacity = 0.25
        knob.layer.shadowRadius = 4
        knob.layer.shadowOffset = CGSize(width: 0, height: 2)
        knob.accessibilityLabel = "Protractor arm"
        let knobPan = UIPanGestureRecognizer(target: self, action: #selector(handleKnob))
        knob.addGestureRecognizer(knobPan)
        body.addSubview(knob)
        addSubview(body)

        readout.font = .monospacedDigitSystemFont(ofSize: 17, weight: .bold)
        readout.textColor = .white
        readout.backgroundColor = Palette.stamp
        readout.textAlignment = .center
        readout.layer.cornerRadius = 15
        readout.layer.masksToBounds = true
        addSubview(readout)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleMove))
        pan.maximumNumberOfTouches = 2
        let twist = UIRotationGestureRecognizer(target: self, action: #selector(handleTwist))
        for recognizer in [pan, twist, knobPan] as [UIGestureRecognizer] {
            recognizer.delegate = self
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
        }
        addGestureRecognizer(pan)
        addGestureRecognizer(twist)
        updateArm()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The centre of the baseline in the body's own coordinates.
    private var pivot: CGPoint {
        CGPoint(x: radius + margin, y: radius + margin)
    }

    private func scalePath() -> UIBezierPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: pivot.x - radius, y: pivot.y))
        path.addLine(to: CGPoint(x: pivot.x + radius, y: pivot.y))
        for degree in 0...180 {
            let length: CGFloat = degree % 10 == 0 ? 18 : degree % 5 == 0 ? 11 : 6
            let angle = CGFloat(degree) * .pi / 180
            let outer = point(at: angle, distance: radius)
            let inner = point(at: angle, distance: radius - length)
            path.move(to: outer)
            path.addLine(to: inner)
        }
        // Centre crosshair
        path.move(to: CGPoint(x: pivot.x, y: pivot.y - 14))
        path.addLine(to: CGPoint(x: pivot.x, y: pivot.y))
        return path
    }

    private func addLabels() {
        for degree in stride(from: 0, through: 180, by: 10) {
            let label = CATextLayer()
            label.string = "\(degree)"
            label.fontSize = 11
            label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            label.foregroundColor = UIColor(hex: 0x6E665B).cgColor
            label.alignmentMode = .center
            label.contentsScale = 3
            label.bounds = CGRect(x: 0, y: 0, width: 30, height: 14)
            label.position = point(at: CGFloat(degree) * .pi / 180, distance: radius - 30)
            body.layer.addSublayer(label)
            labels.append(label)
        }
    }

    /// A point on the protractor at an angle above the baseline.
    private func point(at angle: CGFloat, distance: CGFloat) -> CGPoint {
        CGPoint(x: pivot.x + cos(angle) * distance, y: pivot.y - sin(angle) * distance)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBeenPlaced, bounds.width > 0 {
            hasBeenPlaced = true
            protractorCenter = CGPoint(x: bounds.midX, y: bounds.midY + radius / 2)
        }
        place()
    }

    private func place() {
        body.center = protractorCenter
        body.transform = CGAffineTransform(rotationAngle: rotation)
        readout.text = "\(Int(armDegrees.rounded()))°"
        let width = readout.intrinsicContentSize.width + 24
        readout.bounds = CGRect(x: 0, y: 0, width: width, height: 30)
        readout.center = CGPoint(x: protractorCenter.x, y: protractorCenter.y + 26)
    }

    private func updateArm() {
        let angle = armDegrees * .pi / 180
        let path = UIBezierPath()
        path.move(to: pivot)
        path.addLine(to: point(at: angle, distance: radius + 18))
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        arm.path = path.cgPath
        CATransaction.commit()
        knob.center = point(at: angle, distance: radius + 26)
        place()
    }

    // MARK: - Gestures

    /// Only the protractor's face and knob catch touches.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let local = convert(point, to: body)
        if knob.frame.insetBy(dx: -22, dy: -22).contains(local) {
            return true
        }
        let dx = local.x - pivot.x
        let dy = pivot.y - local.y
        return dy >= -8 && dx * dx + dy * dy <= radius * radius
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard self.point(inside: point, with: event) else { return nil }
        let local = convert(point, to: body)
        return knob.frame.insetBy(dx: -22, dy: -22).contains(local) ? knob : self
    }

    @objc private func handleMove(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        protractorCenter.x += translation.x
        protractorCenter.y += translation.y
        recognizer.setTranslation(.zero, in: self)
        place()
    }

    @objc private func handleTwist(_ recognizer: UIRotationGestureRecognizer) {
        rotation += recognizer.rotation
        recognizer.rotation = 0
        place()
    }

    @objc private func handleKnob(_ recognizer: UIPanGestureRecognizer) {
        if recognizer.state == .began {
            haptics.prepare()
        }
        let local = recognizer.location(in: body)
        var degrees = atan2(pivot.y - local.y, local.x - pivot.x) * 180 / .pi
        // Below the baseline, stick to whichever end is nearer.
        if degrees < 0 {
            degrees = degrees < -90 ? 180 : 0
        }
        let snapped = min(max(degrees.rounded(), 0), 180)
        if Int(snapped) % 15 == 0 && Int(snapped) != Int(armDegrees.rounded()) {
            haptics.selectionChanged()
        }
        armDegrees = snapped
        updateArm()
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other.view === self && gestureRecognizer.view === self
    }
}
