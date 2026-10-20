//
//  RulerView.swift
//  Inkpad
//

import UIKit

/// A ruler you can drag with one finger and rotate with two. It snaps to 45°
/// steps, shows its angle, and lines drawn along an edge are straightened.
/// It sits in screen space, over the page, like a real ruler on paper.
final class RulerView: UIView, UIGestureRecognizerDelegate {
    static let thickness: CGFloat = 92

    /// Angle in radians; 0 is horizontal.
    private(set) var angle: CGFloat = 0
    private(set) var rulerCenter: CGPoint = .zero

    private let body = UIView()
    private let ticks = CAShapeLayer()
    private let angleLabel = UILabel()
    private var unsnappedAngle: CGFloat = 0
    private var isSnapped = true
    private var hasBeenPlaced = false
    private let haptics = UISelectionFeedbackGenerator()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        body.backgroundColor = UIColor(hex: 0xF4EEE2, alpha: 0.9)
        body.layer.borderColor = UIColor(hex: 0xBFB3A0).cgColor
        body.layer.borderWidth = 1
        body.layer.cornerRadius = 10
        body.layer.cornerCurve = .continuous
        body.layer.shadowColor = UIColor.black.cgColor
        body.layer.shadowOpacity = 0.18
        body.layer.shadowRadius = 10
        body.layer.shadowOffset = CGSize(width: 0, height: 4)
        ticks.strokeColor = UIColor(hex: 0x6E665B).cgColor
        ticks.lineWidth = 1
        body.layer.addSublayer(ticks)
        addSubview(body)

        angleLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .semibold)
        angleLabel.textColor = .white
        angleLabel.backgroundColor = Palette.stamp
        angleLabel.textAlignment = .center
        angleLabel.layer.cornerRadius = 14
        angleLabel.layer.masksToBounds = true
        addSubview(angleLabel)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
        pan.maximumNumberOfTouches = 2
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        for recognizer in [pan, rotation, doubleTap] as [UIGestureRecognizer] {
            recognizer.delegate = self
            recognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.direct.rawValue)]
            addGestureRecognizer(recognizer)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Geometry

    private var length: CGFloat {
        max(bounds.width, bounds.height) * 2.4
    }

    private var direction: CGPoint {
        CGPoint(x: cos(angle), y: sin(angle))
    }

    private var normal: CGPoint {
        CGPoint(x: -sin(angle), y: cos(angle))
    }

    /// The two drawing edges as (point on edge, outward normal), in this view's coordinates.
    var edges: [(point: CGPoint, normal: CGPoint)] {
        let half = RulerView.thickness / 2
        let n = normal
        return [
            (CGPoint(x: rulerCenter.x - n.x * half, y: rulerCenter.y - n.y * half), CGPoint(x: -n.x, y: -n.y)),
            (CGPoint(x: rulerCenter.x + n.x * half, y: rulerCenter.y + n.y * half), n),
        ]
    }

    var directionVector: CGPoint { direction }

    override func layoutSubviews() {
        super.layoutSubviews()
        if !hasBeenPlaced, bounds.width > 0 {
            hasBeenPlaced = true
            rulerCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        }
        updateBody()
    }

    private func updateBody() {
        body.transform = .identity
        body.bounds = CGRect(x: 0, y: 0, width: length, height: RulerView.thickness)
        body.center = rulerCenter
        body.transform = CGAffineTransform(rotationAngle: angle)
        updateTicks()

        let degrees = displayedDegrees
        angleLabel.text = "\(degrees)°"
        let size = CGSize(width: angleLabel.intrinsicContentSize.width + 22, height: 28)
        angleLabel.bounds = CGRect(origin: .zero, size: size)
        angleLabel.center = rulerCenter
    }

    private func updateTicks() {
        let path = UIBezierPath()
        let spacing: CGFloat = 8
        var x: CGFloat = 0
        var index = 0
        while x <= length {
            let size: CGFloat = index % 10 == 0 ? 18 : (index % 5 == 0 ? 12 : 7)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size))
            path.move(to: CGPoint(x: x, y: RulerView.thickness))
            path.addLine(to: CGPoint(x: x, y: RulerView.thickness - size))
            x += spacing
            index += 1
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ticks.frame = CGRect(x: 0, y: 0, width: length, height: RulerView.thickness)
        ticks.path = path.cgPath
        CATransaction.commit()
    }

    /// The angle a reader expects: 0–179°, since a ruler looks the same flipped.
    private var displayedDegrees: Int {
        let degrees = Int((angle * 180 / .pi).rounded())
        return ((degrees % 180) + 180) % 180
    }

    /// Only the ruler itself catches touches; everywhere else goes to the page.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let dx = point.x - rulerCenter.x
        let dy = point.y - rulerCenter.y
        let along = dx * direction.x + dy * direction.y
        let across = dx * normal.x + dy * normal.y
        return abs(across) <= RulerView.thickness / 2 && abs(along) <= length / 2
    }

    // MARK: - Moving

    func setAngle(degrees: CGFloat, animated: Bool) {
        let radians = degrees * .pi / 180
        unsnappedAngle = radians
        angle = radians
        haptics.selectionChanged()
        if animated {
            UIView.animate(withDuration: 0.25, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
                self.updateBody()
            }
        } else {
            updateBody()
        }
    }

    func rotate(byDegrees degrees: CGFloat) {
        setAngle(degrees: (angle * 180 / .pi).rounded() + degrees, animated: true)
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        rulerCenter.x += translation.x
        rulerCenter.y += translation.y
        recognizer.setTranslation(.zero, in: self)
        updateBody()
    }

    @objc private func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        if recognizer.state == .began {
            unsnappedAngle = angle
            haptics.prepare()
        }
        unsnappedAngle += recognizer.rotation
        recognizer.rotation = 0

        // Snap to 0°, 45°, 90° and 135° when close.
        let step = CGFloat.pi / 4
        let nearest = (unsnappedAngle / step).rounded() * step
        let snaps = abs(unsnappedAngle - nearest) < 2.5 * .pi / 180
        angle = snaps ? nearest : unsnappedAngle
        if snaps && !isSnapped {
            haptics.selectionChanged()
        }
        isSnapped = snaps
        updateBody()
    }

    @objc private func handleDoubleTap() {
        setAngle(degrees: 0, animated: true)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        other.view === self
    }
}

/// Angle shortcuts shown while the ruler is out.
final class RulerControlsView: UIView {
    var onRotate: ((CGFloat) -> Void)?
    var onSetAngle: ((CGFloat) -> Void)?

    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.deskRaised
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous
        layer.borderColor = Palette.hairline.cgColor
        layer.borderWidth = 0.5
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.14
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)

        stack.axis = .horizontal
        stack.spacing = 2
        addSubview(stack)

        addButton(symbol: "rotate.left", label: "Rotate 15° left") { [weak self] in self?.onRotate?(-15) }
        for degrees in [0, 45, 90] {
            addButton(title: "\(degrees)°", label: "Set ruler to \(degrees)°") { [weak self] in self?.onSetAngle?(CGFloat(degrees)) }
        }
        addButton(symbol: "rotate.right", label: "Rotate 15° right") { [weak self] in self?.onRotate?(15) }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func addButton(symbol: String? = nil, title: String? = nil, label: String, action: @escaping () -> Void) {
        var configuration = UIButton.Configuration.plain()
        configuration.baseForegroundColor = Palette.ink
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        if let symbol {
            configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        }
        if let title {
            configuration.attributedTitle = AttributedString(title, attributes: AttributeContainer([.font: UIFont.monospacedDigitSystemFont(ofSize: 15, weight: .semibold)]))
        }
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.accessibilityLabel = label
        stack.addArrangedSubview(button)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let content = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        return CGSize(width: content.width + 12, height: 44)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        stack.frame = bounds.insetBy(dx: 6, dy: 0)
    }
}
