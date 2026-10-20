//
//  TextBoxOverlay.swift
//  Inkpad
//

import UIKit

/// Holds a notebook's typed text boxes in canvas coordinates, above the ink.
/// It scrolls and zooms with the pages. With the Text tool, tapping empty
/// space starts a new box, and boxes can be edited, moved and deleted.
final class TextBoxOverlay: UIView, UITextViewDelegate {
    /// Called with every box (canvas coordinates) whenever one changes.
    var onChange: (([TextBox]) -> Void)?
    /// Called when a box starts editing, so the canvas can bring it into view.
    var onBeginEditing: ((CGRect) -> Void)?
    /// How wide a new box can be, given where it starts (to stay on the page).
    var availableWidth: ((CGPoint) -> CGFloat)?

    var isOnDarkPaper = false {
        didSet { views.values.forEach { $0.isOnDarkPaper = isOnDarkPaper } }
    }

    /// Style for new boxes, and for the box being edited.
    var style: (fontSize: CGFloat, color: UIColor) = (22, .black) {
        didSet { applyStyleToEditingBox() }
    }

    var isEditable = false {
        didSet {
            guard isEditable != oldValue else { return }
            isUserInteractionEnabled = isEditable
            if !isEditable {
                endEditing(true)
            }
            views.values.forEach { $0.showsChrome = isEditable }
        }
    }

    private var views: [UUID: TextBoxView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var boxes: [TextBox] {
        views.values.map(\.box)
    }

    func setBoxes(_ boxes: [TextBox]) {
        views.values.forEach { $0.removeFromSuperview() }
        views = [:]
        boxes.forEach { addView(for: $0) }
    }

    /// Adds a box, e.g. from handwriting the Text Pen converted.
    @discardableResult
    func add(_ box: TextBox, beginEditing: Bool) -> TextBox {
        let view = addView(for: box)
        if beginEditing {
            view.textView.becomeFirstResponder()
        }
        notifyChange()
        return box
    }

    func remove(id: UUID) {
        views[id]?.removeFromSuperview()
        views[id] = nil
        notifyChange()
    }

    /// Re-renders text crisply after zooming.
    func updateResolution(_ scale: CGFloat) {
        func apply(_ view: UIView) {
            view.contentScaleFactor = scale
            view.subviews.forEach(apply)
        }
        views.values.forEach(apply)
    }

    @discardableResult
    private func addView(for box: TextBox) -> TextBoxView {
        let view = TextBoxView(box: box)
        view.isOnDarkPaper = isOnDarkPaper
        view.showsChrome = isEditable
        view.textView.delegate = self
        view.onMove = { [weak self] in self?.notifyChange() }
        view.onDelete = { [weak self, weak view] in
            guard let self, let view else { return }
            remove(id: view.box.id)
        }
        addSubview(view)
        views[box.id] = view
        return view
    }

    // MARK: - Creating

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        if hitTest(point, with: nil) is TextBoxView || hitTest(point, with: nil)?.superview is TextBoxView {
            return
        }
        // The first tap away from a box just finishes editing it.
        if views.values.contains(where: { $0.textView.isFirstResponder }) {
            endEditing(true)
            return
        }
        let width = min(max(availableWidth?(point) ?? 400, 160), 520)
        let box = TextBox(
            x: point.x,
            y: point.y - style.fontSize * 0.7,
            width: width,
            text: "",
            fontSize: style.fontSize,
            colorHex: style.color.hexString
        )
        add(box, beginEditing: true)
    }

    private func applyStyleToEditingBox() {
        guard let view = views.values.first(where: { $0.textView.isFirstResponder }) else { return }
        view.box.fontSize = style.fontSize
        view.box.colorHex = style.color.hexString
        view.refresh()
        notifyChange()
    }

    private func notifyChange() {
        onChange?(boxes)
    }

    // MARK: - UITextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
        guard let view = textView.superview as? TextBoxView else { return }
        onBeginEditing?(view.frame)
    }

    func textViewDidChange(_ textView: UITextView) {
        guard let view = textView.superview as? TextBoxView else { return }
        view.box.text = textView.text
        view.refresh()
        notifyChange()
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        guard let view = textView.superview as? TextBoxView else { return }
        // A box left empty goes away.
        if view.box.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            remove(id: view.box.id)
        }
    }
}

/// One text box: the text, plus a grip to drag it and a delete button while
/// the Text tool is selected.
final class TextBoxView: UIView {
    var box: TextBox
    let textView = UITextView()
    var onMove: (() -> Void)?
    var onDelete: (() -> Void)?

    var isOnDarkPaper = false {
        didSet { refresh() }
    }

    var showsChrome = false {
        didSet {
            grip.isHidden = !showsChrome
            deleteButton.isHidden = !showsChrome
            outline.isHidden = !showsChrome
            textView.isEditable = showsChrome
            textView.isSelectable = showsChrome
        }
    }

    private let grip = UIImageView(image: UIImage(systemName: "line.3.horizontal", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
    private let deleteButton = UIButton(type: .system)
    private let outline = CAShapeLayer()

    init(box: TextBox) {
        self.box = box
        super.init(frame: box.frame)
        clipsToBounds = false

        outline.fillColor = nil
        outline.strokeColor = Palette.stamp.withAlphaComponent(0.5).cgColor
        outline.lineDashPattern = [4, 3]
        outline.lineWidth = 1
        layer.addSublayer(outline)

        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)

        grip.tintColor = .white
        grip.backgroundColor = Palette.stamp
        grip.contentMode = .center
        grip.layer.cornerRadius = 11
        grip.clipsToBounds = true
        grip.isUserInteractionEnabled = true
        grip.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleDrag)))
        grip.accessibilityLabel = "Move text"
        addSubview(grip)

        deleteButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold)), for: .normal)
        deleteButton.tintColor = .white
        deleteButton.backgroundColor = Palette.inkSecondary
        deleteButton.layer.cornerRadius = 11
        deleteButton.accessibilityLabel = "Delete text"
        deleteButton.addAction(UIAction { [weak self] _ in self?.onDelete?() }, for: .primaryActionTriggered)
        addSubview(deleteButton)

        showsChrome = false
        refresh()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refresh() {
        let selection = textView.selectedRange
        textView.font = box.font
        textView.textColor = box.displayColor(onDarkPaper: isOnDarkPaper)
        if textView.text != box.text {
            textView.text = box.text
        }
        textView.selectedRange = selection
        frame = box.frame
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textView.frame = bounds
        grip.frame = CGRect(x: 0, y: -28, width: 34, height: 22)
        deleteButton.frame = CGRect(x: bounds.width - 22, y: -28, width: 22, height: 22)
        outline.path = UIBezierPath(roundedRect: bounds.insetBy(dx: -6, dy: -4), cornerRadius: 6).cgPath
    }

    /// The grip and delete button sit above the box, so let them receive taps.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        super.point(inside: point, with: event)
            || (showsChrome && (grip.frame.contains(point) || deleteButton.frame.contains(point)))
    }

    @objc private func handleDrag(_ recognizer: UIPanGestureRecognizer) {
        guard let container = superview else { return }
        let translation = recognizer.translation(in: container)
        box.x += translation.x
        box.y += translation.y
        recognizer.setTranslation(.zero, in: container)
        frame = box.frame
        if recognizer.state == .ended {
            onMove?()
        }
    }
}
