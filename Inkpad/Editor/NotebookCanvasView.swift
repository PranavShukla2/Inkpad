//
//  NotebookCanvasView.swift
//  Inkpad
//

import UIKit
import PencilKit

/// The whole notebook as one PencilKit canvas: pages are stacked vertically and
/// drawn underneath the ink, so zoom and scrolling stay native and sharp.
final class NotebookCanvasView: UIView, PKCanvasViewDelegate, UIPencilInteractionDelegate {
    let canvasView = PKCanvasView()

    var onDrawingChanged: (() -> Void)?
    var onCurrentPageChanged: ((Int) -> Void)?
    var onPencilTap: ((UIPencilPreferredAction) -> Void)?

    /// Space for the editor's top bar; pages scroll underneath it.
    var topInset: CGFloat = 0 {
        didSet {
            guard topInset != oldValue else { return }
            canvasView.contentInset.top = topInset
            canvasView.verticalScrollIndicatorInsets.top = topInset
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

        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = self
        addInteraction(pencilInteraction)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Content

    func load(specs: [PageSpec], paperColor: PaperColor, pdf: CGPDFDocument?, scrollTo pageIndex: Int? = nil) {
        isLoading = true
        defer { isLoading = false }

        backgrounds = specs.map { spec in
            if let pdfPageIndex = spec.pdfPageIndex, let page = pdf?.page(at: pdfPageIndex + 1) {
                .pdf(page)
            } else {
                .paper(spec.paperStyle, paperColor)
            }
        }
        layout = PageLayout(sizes: specs.map(\.size))
        canvasView.overrideUserInterfaceStyle = paperColor.isDark ? .dark : .light

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
        let zoom = canvasView.zoomScale
        let maxOffset = max(-canvasView.contentInset.top, canvasView.contentSize.height - canvasView.bounds.height)
        let y = (layout.frames[index].minY - PageLayout.gap / 2) * zoom - canvasView.contentInset.top
        canvasView.setContentOffset(CGPoint(x: canvasView.contentOffset.x, y: min(y, maxOffset)), animated: animated)
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

        // Zoomed all the way out, the widest page fills the width.
        let newFitScale = bounds.width / layout.contentSize.width
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
    }

    private func updateContentSize() {
        let zoom = canvasView.zoomScale
        canvasView.contentSize = CGSize(width: layout.contentSize.width * zoom, height: layout.contentSize.height * zoom)
        pagesContainer.transform = CGAffineTransform(scaleX: zoom, y: zoom)
        pagesContainer.layer.position = .zero
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
        let needed = Set(layout.pageIndices(in: visible.insetBy(dx: 0, dy: -visible.height / 2)))

        for (index, slot) in slots where !needed.contains(index) {
            slot.removeFromSuperview()
            slots[index] = nil
        }
        for index in needed where slots[index] == nil {
            let slot = PageSlotView(frame: layout.frames[index], background: backgrounds[index])
            pagesContainer.addSubview(slot)
            slots[index] = slot
        }

        let topEdge = visible.minY + canvasView.contentInset.top / zoom
        let pageIndex = layout.pageIndex(at: topEdge + (visible.maxY - topEdge) / 3)
        if pageIndex != currentPageIndex {
            currentPageIndex = pageIndex
            onCurrentPageChanged?(pageIndex)
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

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateContentSize()
        updateVisiblePages()
    }

    // MARK: - UIPencilInteractionDelegate

    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        onPencilTap?(UIPencilInteraction.preferredTapAction)
    }
}
