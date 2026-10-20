//
//  NotebookCanvasView.swift
//  Inkpad
//

import UIKit
import PencilKit

/// The whole notebook as one PencilKit canvas: pages are laid out in a column
/// or a row and drawn underneath the ink, so zoom and scrolling stay native and sharp.
final class NotebookCanvasView: UIView, PKCanvasViewDelegate, UIPencilInteractionDelegate {
    let canvasView = PKCanvasView()

    var onDrawingChanged: (() -> Void)?
    var onCurrentPageChanged: ((Int) -> Void)?
    var onPencilTap: ((UIPencilPreferredAction) -> Void)?
    /// Pulling past the last page asks for a new one.
    var onAddPageRequested: (() -> Void)?

    /// Space for the editor's top bar; pages scroll underneath it.
    var topInset: CGFloat = 0 {
        didSet {
            guard topInset != oldValue else { return }
            setNeedsLayout()
        }
    }

    private(set) var layout = PageLayout(sizes: [])
    private(set) var currentPageIndex = 0
    private let pagesContainer = UIView()
    private var backgrounds: [PageBackground] = []
    private var slots: [Int: PageSlotView] = [:]
    private var fitScale: CGFloat = 0
    private var isLoading = false
    /// Snap new strokes to clean shapes (the Shapes tool).
    private var snapsShapes = false
    private var isSnapping = false
    private var strokeCount = 0
    private var appliedToolKey: String?
    /// A page to show once the view has a size.
    private var pendingScrollIndex: Int?

    private let pullIndicator = PullToAddView()
    private let pullThreshold: CGFloat = 90
    private var isPullArmed = false
    private var dragStartPageIndex = 0
    private let haptics = UIImpactFeedbackGenerator(style: .medium)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Palette.desk

        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.delegate = self
        canvasView.contentInsetAdjustmentBehavior = .never
        canvasView.alwaysBounceVertical = true
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.bouncesZoom = true

        // Pages live under PencilKit's own views and are scaled to match its zoom.
        pagesContainer.layer.anchorPoint = .zero
        pagesContainer.isUserInteractionEnabled = false
        canvasView.insertSubview(pagesContainer, at: 0)
        addSubview(canvasView)

        pullIndicator.alpha = 0
        addSubview(pullIndicator)

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Content

    func load(specs: [PageSpec], paperColor: PaperColor, pdf: CGPDFDocument?, axis: ScrollAxis, scrollTo pageIndex: Int? = nil) {
        isLoading = true
        defer { isLoading = false }

        backgrounds = specs.map { spec in
            if let pdfPageIndex = spec.pdfPageIndex, let page = pdf?.page(at: pdfPageIndex + 1) {
                .pdf(page)
            } else {
                .paper(spec.paperStyle, paperColor)
            }
        }
        layout = PageLayout(sizes: specs.map(\.size), axis: axis)
        canvasView.overrideUserInterfaceStyle = paperColor.isDark ? .dark : .light
        canvasView.alwaysBounceVertical = axis == .vertical
        canvasView.alwaysBounceHorizontal = axis == .horizontal
        canvasView.decelerationRate = axis == .horizontal ? .fast : .normal
        pullIndicator.axis = axis

        slots.values.forEach { $0.removeFromSuperview() }
        slots = [:]
        pagesContainer.bounds = CGRect(origin: .zero, size: layout.contentSize)

        canvasView.drawing = layout.merge(specs.map(\.drawing))
        canvasView.undoManager?.removeAllActions()
        strokeCount = canvasView.drawing.strokes.count

        fitScale = 0
        pendingScrollIndex = pageIndex
        setNeedsLayout()
        layoutIfNeeded()
    }

    /// The current ink, one drawing per page in page coordinates.
    func pageDrawings() -> [PKDrawing] {
        layout.split(canvasView.drawing)
    }

    func scrollToPage(_ index: Int, animated: Bool) {
        guard layout.frames.indices.contains(index) else { return }
        canvasView.setContentOffset(offset(showingPage: index), animated: animated)
    }

    private func offset(showingPage index: Int) -> CGPoint {
        let zoom = canvasView.zoomScale
        let inset = canvasView.contentInset
        let frame = layout.frames[index]
        switch layout.axis {
        case .vertical:
            let maxY = max(-inset.top, canvasView.contentSize.height + inset.bottom - canvasView.bounds.height)
            let y = (frame.minY - PageLayout.gap / 2) * zoom - inset.top
            return CGPoint(x: canvasView.contentOffset.x, y: min(max(y, -inset.top), maxY))
        case .horizontal:
            let maxX = max(-inset.left, canvasView.contentSize.width + inset.right - canvasView.bounds.width)
            let x = frame.midX * zoom - canvasView.bounds.width / 2
            return CGPoint(x: min(max(x, -inset.left), maxX), y: -inset.top)
        }
    }

    // MARK: - Tools

    func apply(tool: @autoclosure () -> PKTool, key: String, isRulerActive: Bool, allowsFingerDrawing: Bool, snapsShapes: Bool) {
        self.snapsShapes = snapsShapes
        if key != appliedToolKey {
            appliedToolKey = key
            canvasView.tool = tool()
        }
        if canvasView.isRulerActive != isRulerActive {
            canvasView.isRulerActive = isRulerActive
        }
        // With Pencil-only drawing, fingers scroll and zoom.
        let policy: PKCanvasViewDrawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        if canvasView.drawingPolicy != policy {
            canvasView.drawingPolicy = policy
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        canvasView.frame = bounds
        guard bounds.width > 0, layout.contentSize.width > 0 else { return }

        // Zoomed all the way out, a page fills the width (or, side by side, the screen).
        let newFitScale = fittingScale()
        if newFitScale != fitScale {
            let relativeZoom = fitScale > 0 ? canvasView.zoomScale / fitScale : 1
            fitScale = newFitScale
            canvasView.minimumZoomScale = newFitScale
            canvasView.maximumZoomScale = newFitScale * 5
            canvasView.zoomScale = newFitScale * max(1, relativeZoom)
        }
        updateContentSize()
        if let pendingScrollIndex {
            self.pendingScrollIndex = nil
            scrollToPage(pendingScrollIndex, animated: false)
        }
        updateVisiblePages()
        layoutPullIndicator()
    }

    private func fittingScale() -> CGFloat {
        switch layout.axis {
        case .vertical:
            return bounds.width / layout.contentSize.width
        case .horizontal:
            let page = layout.maxPageSize
            let availableHeight = bounds.height - topInset
            return min(
                bounds.width / (page.width + PageLayout.sideMargin * 2),
                availableHeight / layout.contentSize.height
            )
        }
    }

    private func updateContentSize() {
        let zoom = canvasView.zoomScale
        canvasView.contentSize = CGSize(width: layout.contentSize.width * zoom, height: layout.contentSize.height * zoom)
        pagesContainer.transform = CGAffineTransform(scaleX: zoom, y: zoom)
        pagesContainer.layer.position = .zero
        updateInsets()
    }

    /// Centres content that is smaller than the screen, and lets the first and
    /// last pages sit in the middle when pages are side by side.
    private func updateInsets() {
        let zoom = canvasView.zoomScale
        let content = canvasView.contentSize
        let availableHeight = bounds.height - topInset
        var horizontal = max(0, (bounds.width - content.width) / 2)
        if layout.axis == .horizontal {
            let pageWidth = (layout.maxPageSize.width + PageLayout.sideMargin * 2) * zoom
            horizontal = max(horizontal, (bounds.width - pageWidth) / 2)
        }
        let vertical = max(0, (availableHeight - content.height) / 2)
        let insets = UIEdgeInsets(top: topInset + vertical, left: horizontal, bottom: vertical, right: horizontal)
        if canvasView.contentInset != insets {
            canvasView.contentInset = insets
            canvasView.verticalScrollIndicatorInsets.top = topInset
        }
    }

    /// Keeps page views only for pages on or near the screen.
    private func updateVisiblePages() {
        let zoom = canvasView.zoomScale
        guard zoom > 0, !layout.frames.isEmpty else { return }

        let visible = CGRect(
            x: canvasView.contentOffset.x / zoom,
            y: canvasView.contentOffset.y / zoom,
            width: canvasView.bounds.width / zoom,
            height: canvasView.bounds.height / zoom
        )
        let margin = layout.axis == .vertical
            ? visible.insetBy(dx: 0, dy: -visible.height / 2)
            : visible.insetBy(dx: -visible.width / 2, dy: 0)
        let needed = Set(layout.pageIndices(in: margin))

        for (index, slot) in slots where !needed.contains(index) {
            slot.removeFromSuperview()
            slots[index] = nil
        }
        for index in needed where slots[index] == nil {
            let slot = PageSlotView(frame: layout.frames[index], background: backgrounds[index])
            pagesContainer.addSubview(slot)
            slots[index] = slot
        }

        let pageIndex: Int
        switch layout.axis {
        case .vertical:
            let topEdge = visible.minY + topInset / zoom
            pageIndex = layout.pageIndex(at: CGPoint(x: visible.midX, y: topEdge + (visible.maxY - topEdge) / 3))
        case .horizontal:
            pageIndex = layout.pageIndex(at: CGPoint(x: visible.midX, y: visible.midY))
        }
        if pageIndex != currentPageIndex {
            currentPageIndex = pageIndex
            onCurrentPageChanged?(pageIndex)
        }
    }

    // MARK: - Pull to add a page

    /// How far the user has dragged past the end of the last page.
    private var overscroll: CGFloat {
        let offset = canvasView.contentOffset
        let inset = canvasView.contentInset
        switch layout.axis {
        case .vertical:
            return offset.y + canvasView.bounds.height - (canvasView.contentSize.height + inset.bottom)
        case .horizontal:
            return offset.x + canvasView.bounds.width - (canvasView.contentSize.width + inset.right)
        }
    }

    private func updatePullIndicator() {
        guard onAddPageRequested != nil, canvasView.isDragging else {
            if !isPullArmed {
                pullIndicator.alpha = 0
            }
            return
        }
        let amount = overscroll
        let progress = min(max(amount / pullThreshold, 0), 1)
        pullIndicator.alpha = progress
        layoutPullIndicator()

        let shouldArm = amount >= pullThreshold
        if shouldArm != isPullArmed {
            isPullArmed = shouldArm
            pullIndicator.isArmed = shouldArm
            if shouldArm {
                haptics.impactOccurred()
            }
        }
    }

    private func layoutPullIndicator() {
        let size = pullIndicator.sizeThatFits(bounds.size)
        switch layout.axis {
        case .vertical:
            pullIndicator.frame = CGRect(x: (bounds.width - size.width) / 2, y: bounds.height - size.height - 28, width: size.width, height: size.height)
        case .horizontal:
            pullIndicator.frame = CGRect(x: bounds.width - size.width - 20, y: topInset + (bounds.height - topInset - size.height) / 2, width: size.width, height: size.height)
        }
    }

    // MARK: - PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isLoading else { return }
        let addedOneStroke = canvasView.drawing.strokes.count == strokeCount + 1
        strokeCount = canvasView.drawing.strokes.count
        if snapsShapes, !isSnapping, addedOneStroke {
            snapLastStroke()
        }
        onDrawingChanged?()
    }

    /// Replaces the stroke just drawn with a clean shape, undoably.
    private func snapLastStroke() {
        let before = canvasView.drawing
        guard let stroke = before.strokes.last, let shape = ShapeRecognizer.recognize(stroke) else { return }
        var after = before
        after.strokes[after.strokes.count - 1] = shape
        setDrawing(after, undoingTo: before)
    }

    private func setDrawing(_ drawing: PKDrawing, undoingTo previous: PKDrawing) {
        isSnapping = true
        canvasView.drawing = drawing
        isSnapping = false
        canvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.setDrawing(previous, undoingTo: drawing)
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
        updatePullIndicator()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateContentSize()
        updateVisiblePages()
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartPageIndex = currentPageIndex
        haptics.prepare()
    }

    /// Side by side and zoomed out, pages snap into place one at a time.
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard layout.axis == .horizontal, canvasView.zoomScale <= fitScale * 1.02, !isPullArmed else { return }
        var target = currentPageIndex
        if velocity.x > 0.25 {
            target = dragStartPageIndex + 1
        } else if velocity.x < -0.25 {
            target = dragStartPageIndex - 1
        }
        target = min(max(target, 0), layout.frames.count - 1)
        targetContentOffset.pointee = offset(showingPage: target)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard isPullArmed else { return }
        isPullArmed = false
        pullIndicator.isArmed = false
        UIView.animate(withDuration: 0.2) {
            self.pullIndicator.alpha = 0
        }
        onAddPageRequested?()
    }

    // MARK: - UIPencilInteractionDelegate

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        onPencilTap?(UIPencilInteraction.preferredTapAction)
    }
}

/// "Pull to add a page" pill that turns stamp red once releasing will add one.
private final class PullToAddView: UIView {
    var axis: ScrollAxis = .vertical {
        didSet { update() }
    }

    var isArmed = false {
        didSet {
            guard isArmed != oldValue else { return }
            UIView.animate(withDuration: 0.18) {
                self.update()
            }
        }
    }

    private let icon = UIImageView()
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 3)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        icon.contentMode = .scaleAspectFit
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        addSubview(icon)
        addSubview(label)
        update()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func update() {
        label.text = isArmed ? "Release to add a page" : "Pull to add a page"
        let symbol = isArmed ? "plus.rectangle.portrait" : (axis == .vertical ? "arrow.up" : "arrow.left")
        icon.image = UIImage(systemName: symbol)
        backgroundColor = isArmed ? Palette.stamp : Palette.deskRaised
        label.textColor = isArmed ? .white : Palette.ink
        icon.tintColor = label.textColor
        transform = isArmed ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let text = label.intrinsicContentSize
        return CGSize(width: text.width + 58, height: 40)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        icon.frame = CGRect(x: 16, y: (bounds.height - 18) / 2, width: 18, height: 18)
        let text = label.intrinsicContentSize
        label.frame = CGRect(x: 42, y: (bounds.height - text.height) / 2, width: text.width, height: text.height)
    }
}
