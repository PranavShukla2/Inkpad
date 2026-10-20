//
//  BoardItemsOverlay.swift
//  Inkpad
//

import UIKit

/// Shows sticky notes, shapes, photos and graphs in canvas coordinates,
/// beneath the ink. It scrolls and zooms with the pages; touches are handled
/// by the canvas, so the Pencil can still write over items.
final class BoardItemsOverlay: UIView {
    var imageProvider: ((UUID) -> UIImage?)?
    private(set) var items: [BoardItem] = []
    private var views: [UUID: BoardItemView] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setItems(_ newItems: [BoardItem]) {
        items = newItems
        let ids = Set(newItems.map(\.id))
        for (id, view) in views where !ids.contains(id) {
            view.removeFromSuperview()
            views[id] = nil
        }
        for item in newItems {
            let view = views[item.id] ?? BoardItemView()
            if views[item.id] == nil {
                views[item.id] = view
            }
            view.update(item, image: item.imageID.flatMap { imageProvider?($0) })
            // Array order is stacking order.
            addSubview(view)
        }
    }

    /// The topmost item under a point in canvas coordinates.
    func item(at point: CGPoint) -> BoardItem? {
        items.last { $0.frame.contains(point) }
    }

    /// Moves an item's view without committing, for smooth dragging.
    func preview(_ item: BoardItem) {
        views[item.id]?.update(item, image: item.imageID.flatMap { imageProvider?($0) })
    }

    func updateResolution(_ scale: CGFloat) {
        for view in views.values where view.contentScaleFactor != scale {
            view.contentScaleFactor = scale
            view.setNeedsDisplay()
        }
    }
}

final class BoardItemView: UIView {
    private(set) var item: BoardItem?
    private var image: UIImage?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(_ item: BoardItem, image: UIImage?) {
        let needsRedraw = self.item?.text != item.text
            || self.item?.colorHex != item.colorHex
            || self.item?.shape != item.shape
            || self.item?.domainMin != item.domainMin
            || self.item?.domainMax != item.domainMax
            || self.item?.frame.size != item.frame.size
            || self.image !== image
        self.item = item
        self.image = image
        frame = item.frame

        // Paper-like items cast a soft shadow; shapes sit flat on the page.
        let castsShadow = item.kind != .shape
        layer.shadowOpacity = castsShadow ? 0.16 : 0
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowPath = castsShadow ? UIBezierPath(rect: bounds).cgPath : nil
        if needsRedraw {
            setNeedsDisplay()
        }
    }

    override func draw(_ rect: CGRect) {
        guard let item, let context = UIGraphicsGetCurrentContext() else { return }
        BoardItemRenderer.draw(item, image: image, in: bounds, context: context, drawsShadow: false)
    }
}

/// Outline, resize handle and actions for the selected item, in screen space
/// so they stay the same size at any zoom.
final class SelectionChromeView: UIView {
    var onResize: ((CGPoint, UIGestureRecognizer.State) -> Void)?
    var onDelete: (() -> Void)?
    var onDuplicate: (() -> Void)?
    var onBringToFront: (() -> Void)?
    var onEdit: (() -> Void)?
    var onColor: ((String) -> Void)?

    private let outline = CAShapeLayer()
    private let handle = UIView()
    private let actions = UIStackView()
    private var itemRect: CGRect = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        outline.fillColor = nil
        outline.strokeColor = Palette.stamp.cgColor
        outline.lineWidth = 1.5
        outline.lineDashPattern = [6, 4]
        layer.addSublayer(outline)

        handle.backgroundColor = .white
        handle.layer.borderColor = Palette.stamp.cgColor
        handle.layer.borderWidth = 2.5
        handle.layer.cornerRadius = 12
        handle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleResize)))
        handle.accessibilityLabel = "Resize"
        addSubview(handle)

        actions.axis = .horizontal
        actions.spacing = 0
        actions.backgroundColor = Palette.deskRaised
        actions.layer.cornerRadius = 20
        actions.layer.cornerCurve = .continuous
        actions.layer.borderColor = Palette.hairline.cgColor
        actions.layer.borderWidth = 0.5
        actions.layer.shadowColor = UIColor.black.cgColor
        actions.layer.shadowOpacity = 0.15
        actions.layer.shadowRadius = 10
        actions.layer.shadowOffset = CGSize(width: 0, height: 3)
        actions.isLayoutMarginsRelativeArrangement = true
        actions.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 6, bottom: 0, trailing: 6)
        addSubview(actions)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Rebuilds the action bar for the kind of item selected.
    func configure(for item: BoardItem) {
        actions.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch item.kind {
        case .sticky:
            addAction("pencil", label: "Edit Text") { [weak self] in self?.onEdit?() }
            addColorMenu(BoardItem.stickyColors)
        case .shape:
            addColorMenu(BoardItem.shapeColors + BoardItem.stickyColors)
        case .graph:
            addAction("function", label: "Edit Graph") { [weak self] in self?.onEdit?() }
        case .image:
            break
        }
        addAction("plus.square.on.square", label: "Duplicate") { [weak self] in self?.onDuplicate?() }
        addAction("square.stack.3d.up", label: "Bring to Front") { [weak self] in self?.onBringToFront?() }
        addAction("trash", label: "Delete", tint: Palette.stamp) { [weak self] in self?.onDelete?() }
    }

    private func addAction(_ symbol: String, label: String, tint: UIColor = Palette.ink, action: @escaping () -> Void) {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        configuration.baseForegroundColor = tint
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 9, bottom: 10, trailing: 9)
        let button = UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
        button.accessibilityLabel = label
        actions.addArrangedSubview(button)
    }

    private func addColorMenu(_ colors: [String]) {
        let menu = UIMenu(title: "Colour", children: colors.map { hex in
            UIAction(title: "", image: Self.swatch(hex)) { [weak self] _ in self?.onColor?(hex) }
        })
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "paintpalette", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .medium))
        configuration.baseForegroundColor = Palette.ink
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 9, bottom: 10, trailing: 9)
        let button = UIButton(configuration: configuration)
        button.menu = menu
        button.showsMenuAsPrimaryAction = true
        button.accessibilityLabel = "Colour"
        actions.addArrangedSubview(button)
    }

    private static func swatch(_ hex: String) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 24, height: 24)).image { _ in
            (UIColor(hexString: hex) ?? .gray).setFill()
            UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 20, height: 20)).fill()
        }.withRenderingMode(.alwaysOriginal)
    }

    /// Places the chrome around an item's rectangle on screen.
    func place(around rect: CGRect) {
        itemRect = rect
        outline.path = UIBezierPath(roundedRect: rect.insetBy(dx: -4, dy: -4), cornerRadius: 6).cgPath
        handle.frame = CGRect(x: rect.maxX - 12, y: rect.maxY - 12, width: 24, height: 24)
        let size = actions.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        var origin = CGPoint(x: rect.midX - size.width / 2, y: rect.minY - size.height - 14)
        if origin.y < safeAreaInsets.top + 70 {
            origin.y = rect.maxY + 18
        }
        origin.x = min(max(origin.x, 12), bounds.width - size.width - 12)
        actions.frame = CGRect(origin: origin, size: CGSize(width: size.width, height: 40))
    }

    /// Only the handle and actions catch touches; the rest passes to the page.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        handle.frame.insetBy(dx: -10, dy: -10).contains(point) || actions.frame.contains(point)
    }

    @objc private func handleResize(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: self)
        recognizer.setTranslation(.zero, in: self)
        onResize?(translation, recognizer.state)
    }
}
