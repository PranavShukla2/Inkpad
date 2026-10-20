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
    /// Every text box, in canvas coordinates, after any change.
    var onTextBoxesChanged: (([TextBox]) -> Void)?
    /// A short message for the user, e.g. when handwriting couldn't be read.
    var onMessage: ((String) -> Void)?

    let textOverlay = TextBoxOverlay()

    /// Space for the editor's top bar; pages scroll underneath it.
    var topInset: CGFloat = 0 {
        didSet {
            guard topInset != oldValue else { return }
            needsContentLayout = true
            setNeedsLayout()
        }
    }

    private(set) var layout = PageLayout(sizes: [])
    private(set) var currentPageIndex = 0
    private let pagesContainer = UIView()
    private var backgrounds: [PageBackground] = []
    private var slots: [Int: PageSlotView] = [:]
    private var fitScale: CGFloat = 0
    /// Scroll geometry is only recomputed when the size or content changes.
    /// Touching it during an ordinary layout pass snaps back a pull in progress.
    private var needsContentLayout = true
    private var laidOutSize: CGSize = .zero
    private var isLoading = false
    /// Snap new strokes to clean shapes (the Shapes tool).
    private var snapsShapes = false
    private var isReplacingDrawing = false
    private var strokeCount = 0
    /// Text Pen: handwriting waiting to be turned into a text box.
    private var isTextPenActive = false
    private var textPenStrokeCount = 0
    private var textPenWork: DispatchWorkItem?
    private var appliedToolKey: String?
    /// A page to show once the view has a size.
    private var pendingScrollIndex: Int?
    /// A canvas board: one big page you zoom around, rather than pages to flip.
    private var isBoard = false
    /// Zoom and position to restore after reloading, so a growing board doesn't jump.
    private var pendingViewport: (zoom: CGFloat, offset: CGPoint)?
    private var pendingBoardCentering = false

    private let laserOverlay = LaserOverlayView()
    private let laserRecognizer = LaserGestureRecognizer()
    private let eraserTracker = EraserTracker()
    private var eraserSlack: CGFloat = 6
    /// The scroll view's own setting, restored when the laser is put away.
    private var defaultMinimumPanTouches: Int?
    private let ruler = RulerView()
    private var isRulerVisible = false
    private let rulerControls = RulerControlsView()
    private let addPageButton = AddPageButton()
    private let pullIndicator = PullToAddView()
    private let pullThreshold: CGFloat = 110
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
        // Typed text sits above the ink and scales with it like the pages.
        textOverlay.layer.anchorPoint = .zero
        textOverlay.onChange = { [weak self] boxes in
            self?.onTextBoxesChanged?(boxes)
        }
        textOverlay.availableWidth = { [weak self] point in
            guard let self, !layout.frames.isEmpty else { return 400 }
            return layout.frames[layout.pageIndex(at: point)].maxX - point.x - 24
        }
        textOverlay.onBeginEditing = { [weak self] rect in
            self?.revealAboveKeyboard(rect)
        }
        canvasView.addSubview(textOverlay)
        addSubview(canvasView)

        ruler.isHidden = true
        rulerControls.isHidden = true
        rulerControls.onRotate = { [weak self] degrees in
            self?.ruler.rotate(byDegrees: degrees)
        }
        rulerControls.onSetAngle = { [weak self] degrees in
            self?.ruler.setAngle(degrees: degrees, animated: true)
        }
        addSubview(ruler)
        addSubview(rulerControls)

        addSubview(laserOverlay)
        laserRecognizer.isEnabled = false
        laserRecognizer.cancelsTouchesInView = true
        laserRecognizer.onBegan = { [weak self] point in
            self?.laserOverlay.begin(at: point)
        }
        laserRecognizer.onMoved = { [weak self] points in
            self?.laserOverlay.add(points)
        }
        laserRecognizer.onEnded = { [weak self] in
            self?.laserOverlay.end()
        }
        addGestureRecognizer(laserRecognizer)

        eraserTracker.isEnabled = false
        eraserTracker.onMove = { [weak self] point in
            self?.eraseTextBox(at: point)
        }
        canvasView.addGestureRecognizer(eraserTracker)

        addPageButton.addAction(UIAction { [weak self] _ in
            self?.onAddPageRequested?()
        }, for: .primaryActionTriggered)
        addSubview(addPageButton)

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

    func load(
        specs: [PageSpec],
        paperColor: PaperColor,
        pdf: CGPDFDocument?,
        axis: ScrollAxis,
        isBoard: Bool = false,
        scrollTo pageIndex: Int? = nil,
        keepViewport: Bool = false
    ) {
        isLoading = true
        defer { isLoading = false }
        self.isBoard = isBoard
        pendingViewport = keepViewport ? (canvasView.zoomScale, canvasView.contentOffset) : nil
        canvasView.alwaysBounceHorizontal = isBoard

        backgrounds = specs.map { Self.background(for: $0, paperColor: paperColor, pdf: pdf) }
        layout = PageLayout(sizes: specs.map(\.size), axis: axis)
        canvasView.overrideUserInterfaceStyle = paperColor.isDark ? .dark : .light
        canvasView.alwaysBounceVertical = axis == .vertical || isBoard
        canvasView.alwaysBounceHorizontal = axis == .horizontal || isBoard
        canvasView.decelerationRate = axis == .horizontal ? .fast : .normal
        pullIndicator.axis = axis

        slots.values.forEach { $0.removeFromSuperview() }
        slots = [:]
        pagesContainer.bounds = CGRect(origin: .zero, size: layout.contentSize)
        textOverlay.bounds = pagesContainer.bounds
        textOverlay.isOnDarkPaper = paperColor.isDark
        textOverlay.setBoxes(specs.enumerated().flatMap { index, spec in
            spec.textBoxes.map { box in
                var box = box
                box.x += layout.frames[index].minX
                box.y += layout.frames[index].minY
                return box
            }
        })

        canvasView.drawing = layout.merge(specs.map(\.drawing))
        canvasView.undoManager?.removeAllActions()
        strokeCount = canvasView.drawing.strokes.count

        fitScale = 0
        needsContentLayout = true
        // Boards centre on the ink instead of scrolling to a page.
        pendingScrollIndex = keepViewport || isBoard ? nil : pageIndex
        setNeedsLayout()
        layoutIfNeeded()
    }

    private static func background(for spec: PageSpec, paperColor: PaperColor, pdf: CGPDFDocument?) -> PageBackground {
        if let pdfPageIndex = spec.pdfPageIndex, let page = pdf?.page(at: pdfPageIndex + 1) {
            .pdf(page)
        } else {
            .paper(spec.paperStyle, paperColor)
        }
    }

    /// Adds a page after the last one without reloading, keeping the ink, undo
    /// history and zoom, then glides to it. Returns false if the existing pages
    /// would have to move (a wider page), in which case the caller reloads.
    func appendPage(_ spec: PageSpec, paperColor: PaperColor, pdf: CGPDFDocument?) -> Bool {
        let newLayout = PageLayout(sizes: layout.frames.map(\.size) + [spec.size], axis: layout.axis)
        guard Array(newLayout.frames.dropLast()) == layout.frames else { return false }
        layout = newLayout
        backgrounds.append(Self.background(for: spec, paperColor: paperColor, pdf: pdf))
        pagesContainer.bounds = CGRect(origin: .zero, size: layout.contentSize)
        textOverlay.bounds = pagesContainer.bounds
        updateContentSize()
        updateVisiblePages()
        layoutAddPageButton()
        haptics.impactOccurred()
        scrollToPage(layout.frames.count - 1, animated: true)
        return true
    }

    /// Enlarges a canvas board in place, keeping the ink, undo history and view.
    func resizeBoard(to size: CGSize) {
        guard isBoard else { return }
        let offset = canvasView.contentOffset
        layout = PageLayout(sizes: [size], axis: layout.axis)
        pagesContainer.bounds = CGRect(origin: .zero, size: layout.contentSize)
        textOverlay.bounds = pagesContainer.bounds
        slots.values.forEach { $0.removeFromSuperview() }
        slots = [:]
        fitScale = fittingScale()
        canvasView.minimumZoomScale = fitScale
        updateContentSize()
        canvasView.contentOffset = offset
        updateVisiblePages()
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

    func apply(
        tool: @autoclosure () -> PKTool,
        key: String,
        isRulerActive: Bool,
        allowsFingerDrawing: Bool,
        snapsShapes: Bool,
        laserColor: UIColor?,
        laserMode: LaserMode,
        textStyle: (fontSize: CGFloat, color: UIColor)?,
        isTextPen: Bool,
        eraserWidth: CGFloat?
    ) {
        eraserTracker.isEnabled = eraserWidth != nil
        eraserTracker.allowedTouchTypes = allowsFingerDrawing
            ? [NSNumber(value: UITouch.TouchType.pencil.rawValue), NSNumber(value: UITouch.TouchType.direct.rawValue)]
            : [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        eraserSlack = (eraserWidth ?? 12) / 2
        self.snapsShapes = snapsShapes
        if isTextPenActive && !isTextPen {
            // Switching away converts what was written straight away.
            convertTextPenStrokes()
        }
        isTextPenActive = isTextPen
        laserOverlay.mode = laserMode
        applyLaser(color: laserColor, allowsFingerDrawing: allowsFingerDrawing)
        applyText(style: textStyle)
        // The laser and Text tool handle touches themselves.
        let drawingEnabled = laserColor == nil && textStyle == nil
        if canvasView.drawingGestureRecognizer.isEnabled != drawingEnabled {
            canvasView.drawingGestureRecognizer.isEnabled = drawingEnabled
        }
        if key != appliedToolKey {
            appliedToolKey = key
            canvasView.tool = tool()
        }
        if isRulerVisible != isRulerActive {
            showRuler(isRulerActive)
        }
        // With Pencil-only drawing, fingers scroll and zoom.
        let policy: PKCanvasViewDrawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly
        if canvasView.drawingPolicy != policy {
            canvasView.drawingPolicy = policy
        }
    }

    private func showRuler(_ isVisible: Bool) {
        isRulerVisible = isVisible
        if isVisible {
            ruler.isHidden = false
            rulerControls.isHidden = false
        }
        UIView.animate(withDuration: 0.2) {
            self.ruler.alpha = isVisible ? 1 : 0
            self.rulerControls.alpha = isVisible ? 1 : 0
        } completion: { _ in
            self.ruler.isHidden = !self.isRulerVisible
            self.rulerControls.isHidden = !self.isRulerVisible
        }
    }

    private func applyText(style: (fontSize: CGFloat, color: UIColor)?) {
        if let style {
            textOverlay.style = style
            if !textOverlay.isEditable {
                // PencilKit may have added views since; text must be on top to be tapped.
                canvasView.bringSubviewToFront(textOverlay)
            }
        }
        textOverlay.isEditable = style != nil
    }

    /// Erasing over a text box deletes it, undoably.
    private func eraseTextBox(at point: CGPoint) {
        let contentPoint = canvasView.convert(point, to: textOverlay)
        guard let box = textOverlay.box(at: contentPoint, slack: eraserSlack) else { return }
        textOverlay.remove(id: box.id)
        haptics.impactOccurred(intensity: 0.5)
        canvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.textOverlay.add(box, beginEditing: false)
        }
    }

    /// Scrolls a text box being edited into the top part of the screen, clear of the keyboard.
    private func revealAboveKeyboard(_ rect: CGRect) {
        let zoom = canvasView.zoomScale
        let screenBottom = rect.maxY * zoom - canvasView.contentOffset.y
        let limit = bounds.height * 0.45
        guard screenBottom > limit else { return }
        var offset = canvasView.contentOffset
        offset.y += screenBottom - limit
        canvasView.setContentOffset(offset, animated: true)
    }

    /// The laser pen takes over Pencil touches from PencilKit while it's selected.
    private func applyLaser(color: UIColor?, allowsFingerDrawing: Bool) {
        let isActive = color != nil
        if let color {
            laserOverlay.color = color
        }
        laserRecognizer.allowedTouchTypes = allowsFingerDrawing
            ? [NSNumber(value: UITouch.TouchType.pencil.rawValue), NSNumber(value: UITouch.TouchType.direct.rawValue)]
            : [NSNumber(value: UITouch.TouchType.pencil.rawValue)]
        guard laserRecognizer.isEnabled != isActive else { return }
        laserRecognizer.isEnabled = isActive

        // A finger laser needs two fingers to scroll, just like drawing with a finger.
        let pan = canvasView.panGestureRecognizer
        if isActive && allowsFingerDrawing {
            defaultMinimumPanTouches = pan.minimumNumberOfTouches
            pan.minimumNumberOfTouches = 2
        } else if let defaultMinimumPanTouches {
            pan.minimumNumberOfTouches = defaultMinimumPanTouches
            self.defaultMinimumPanTouches = nil
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        if canvasView.frame != bounds {
            canvasView.frame = bounds
            laserOverlay.frame = bounds
            ruler.frame = bounds
        }
        let controlsSize = rulerControls.sizeThatFits(bounds.size)
        rulerControls.frame = CGRect(
            x: (bounds.width - controlsSize.width) / 2,
            y: topInset + 12,
            width: controlsSize.width,
            height: controlsSize.height
        )
        if bounds.size != laidOutSize || needsContentLayout {
            laidOutSize = bounds.size
            needsContentLayout = false
            layoutContent()
        }
        layoutPullIndicator()
        layoutAddPageButton()
    }

    private func layoutContent() {
        guard bounds.width > 0, layout.contentSize.width > 0 else { return }

        // Zoomed all the way out, a page fills the width (or, side by side, the screen).
        let newFitScale = fittingScale()
        if newFitScale != fitScale {
            let wasFresh = fitScale == 0
            let relativeZoom = fitScale > 0 ? canvasView.zoomScale / fitScale : 1
            fitScale = newFitScale
            canvasView.minimumZoomScale = newFitScale
            canvasView.maximumZoomScale = isBoard ? 4 : newFitScale * 5
            if isBoard && wasFresh && pendingViewport == nil {
                pendingBoardCentering = true
            }
            if let pendingViewport {
                canvasView.zoomScale = min(max(pendingViewport.zoom, newFitScale), canvasView.maximumZoomScale)
            } else if isBoard && wasFresh {
                // Open boards at a comfortable writing size, not zoomed all the way out.
                canvasView.zoomScale = max(newFitScale, min(1, bounds.width / 900))
            } else {
                canvasView.zoomScale = newFitScale * max(1, relativeZoom)
            }
        }
        updateContentSize()
        if let pendingViewport {
            self.pendingViewport = nil
            canvasView.contentOffset = pendingViewport.offset
        }
        if pendingBoardCentering {
            pendingBoardCentering = false
            centerBoardOnInk()
        } else if let pendingScrollIndex {
            self.pendingScrollIndex = nil
            scrollToPage(pendingScrollIndex, animated: false)
        }
        updateVisiblePages()
    }

    /// Opens a board looking at your ink, or at the middle of an empty board.
    private func centerBoardOnInk() {
        guard let board = layout.frames.first else { return }
        let ink = canvasView.drawing.bounds
        let target = ink.isNull || ink.isEmpty ? CGPoint(x: board.midX, y: board.midY) : CGPoint(x: ink.midX, y: ink.midY)
        let zoom = canvasView.zoomScale
        canvasView.contentOffset = CGPoint(
            x: target.x * zoom - bounds.width / 2,
            y: target.y * zoom - (bounds.height + topInset) / 2
        )
    }

    private func fittingScale() -> CGFloat {
        if isBoard {
            // Zoom out far enough to get an overview, but not to the whole huge board.
            return max(0.2, min(bounds.width / layout.contentSize.width, (bounds.height - topInset) / layout.contentSize.height))
        }
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
        let contentSize = CGSize(width: layout.contentSize.width * zoom, height: layout.contentSize.height * zoom)
        if canvasView.contentSize != contentSize {
            canvasView.contentSize = contentSize
        }
        pagesContainer.transform = CGAffineTransform(scaleX: zoom, y: zoom)
        pagesContainer.layer.position = .zero
        textOverlay.transform = pagesContainer.transform
        textOverlay.layer.position = .zero
        updateInsets()
    }

    /// Centres content that is smaller than the screen, and lets the first and
    /// last pages sit in the middle when pages are side by side.
    private func updateInsets() {
        let zoom = canvasView.zoomScale
        let content = canvasView.contentSize
        let availableHeight = bounds.height - topInset
        var horizontal = max(0, (bounds.width - content.width) / 2)
        if layout.axis == .horizontal && !isBoard {
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
            let slot = PageSlotView(frame: layout.frames[index], background: backgrounds[index], showsShadow: !isBoard)
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

    // MARK: - Adding pages

    /// Keeps the Add Page button just after the last page as you scroll and zoom.
    private func layoutAddPageButton() {
        guard !isBoard, onAddPageRequested != nil, let last = layout.frames.last else {
            addPageButton.isHidden = true
            return
        }
        let zoom = canvasView.zoomScale
        let offset = canvasView.contentOffset
        let size = addPageButton.sizeThatFits(bounds.size)
        let center: CGPoint
        switch layout.axis {
        case .vertical:
            center = CGPoint(x: last.midX * zoom - offset.x, y: (last.maxY + PageLayout.endMargin / 2) * zoom - offset.y)
        case .horizontal:
            center = CGPoint(x: (last.maxX + PageLayout.endMargin / 2) * zoom - offset.x, y: last.midY * zoom - offset.y)
        }
        addPageButton.bounds = CGRect(origin: .zero, size: size)
        addPageButton.center = center
        addPageButton.isHidden = !bounds.insetBy(dx: -size.width, dy: -size.height).contains(center)
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
        guard onAddPageRequested != nil, !isBoard, canvasView.isDragging else {
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
        if canvasView.drawing.strokes.count < strokeCount {
            textPenStrokeCount = 0
        }
        strokeCount = canvasView.drawing.strokes.count
        if !isReplacingDrawing, addedOneStroke {
            if isTextPenActive {
                textPenStrokeCount += 1
                scheduleTextPenConversion()
            } else if isRulerVisible {
                straightenLastStrokeAlongRuler()
            } else if snapsShapes {
                snapLastStroke()
            }
        }
        onDrawingChanged?()
    }

    func canvasViewDidBeginUsingTool(_ canvasView: PKCanvasView) {
        // Still writing: wait for a pause before converting.
        textPenWork?.cancel()
    }

    // MARK: - Text Pen

    private func scheduleTextPenConversion() {
        textPenWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.convertTextPenStrokes()
        }
        textPenWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1, execute: work)
    }

    /// Reads the Text Pen's handwriting and swaps it for a typed text box.
    private func convertTextPenStrokes() {
        textPenWork?.cancel()
        let count = textPenStrokeCount
        textPenStrokeCount = 0
        let before = canvasView.drawing
        guard count > 0, before.strokes.count >= count else { return }

        let strokes = Array(before.strokes.suffix(count))
        let area = strokes.reduce(CGRect.null) { $0.union($1.renderBounds) }
        let handwriting = PKDrawing(strokes: strokes)
        let expectedStrokeCount = before.strokes.count

        Task { [weak self] in
            let text = await Task.detached(priority: .userInitiated) {
                HandwritingRecognizer.recognizeText(in: handwriting, area: area)
            }.value
            guard let self else { return }
            guard canvasView.drawing.strokes.count == expectedStrokeCount else {
                // More was written meanwhile: convert it all together after the next pause.
                if isTextPenActive {
                    textPenStrokeCount += count
                    scheduleTextPenConversion()
                }
                return
            }
            guard !text.isEmpty else {
                onMessage?("Couldn't read that. Try writing a little larger.")
                return
            }

            let lines = max(1, text.split(separator: "\n").count)
            let fontSize = min(max(area.height / CGFloat(lines) * 0.72, 14), 48)
            let maxWidth = textOverlay.availableWidth?(area.origin) ?? 520
            let box = TextBox(
                x: area.minX,
                y: area.minY,
                width: max(min(area.width + 24, maxWidth), 160),
                text: text,
                fontSize: fontSize,
                colorHex: strokes[0].ink.color.hexString
            )
            var after = before
            after.strokes.removeLast(count)
            applyConversion(removingInk: after, adding: box, restoring: before)
        }
    }

    private func applyConversion(removingInk drawing: PKDrawing, adding box: TextBox, restoring previous: PKDrawing) {
        isReplacingDrawing = true
        canvasView.drawing = drawing
        isReplacingDrawing = false
        textOverlay.add(box, beginEditing: false)
        canvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.undoConversion(of: box, restoring: previous, converted: drawing)
        }
    }

    private func undoConversion(of box: TextBox, restoring drawing: PKDrawing, converted: PKDrawing) {
        isReplacingDrawing = true
        canvasView.drawing = drawing
        isReplacingDrawing = false
        textOverlay.remove(id: box.id)
        canvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.applyConversion(removingInk: converted, adding: box, restoring: drawing)
        }
    }

    /// Replaces the stroke just drawn with a clean shape, undoably.
    private func snapLastStroke() {
        let before = canvasView.drawing
        guard let stroke = before.strokes.last, let shape = ShapeRecognizer.recognize(stroke) else { return }
        var after = before
        after.strokes[after.strokes.count - 1] = shape
        setDrawing(after, undoingTo: before)
    }

    /// A stroke drawn along a ruler edge becomes perfectly straight, keeping the
    /// distance from the edge the user drew at.
    private func straightenLastStrokeAlongRuler() {
        let before = canvasView.drawing
        guard let stroke = before.strokes.last else { return }
        let zoom = canvasView.zoomScale
        let offset = canvasView.contentOffset
        let screenPoints = stroke.path.map { point -> CGPoint in
            let location = point.location.applying(stroke.transform)
            return CGPoint(x: location.x * zoom - offset.x, y: location.y * zoom - offset.y)
        }
        guard screenPoints.count >= 2 else { return }

        let direction = ruler.directionVector
        let tolerance: CGFloat = 22
        for edge in ruler.edges {
            // Signed distance outward from the edge, and position along it.
            let distances = screenPoints.map { ($0.x - edge.point.x) * edge.normal.x + ($0.y - edge.point.y) * edge.normal.y }
            let nearEdge = distances.filter { $0 > -6 && $0 < tolerance }.count
            guard Double(nearEdge) >= Double(distances.count) * 0.85 else { continue }

            let meanDistance = max(0, distances.reduce(0, +) / CGFloat(distances.count))
            let along = screenPoints.map { ($0.x - edge.point.x) * direction.x + ($0.y - edge.point.y) * direction.y }
            guard let minAlong = along.min(), let maxAlong = along.max(), maxAlong - minAlong > 12 else { return }

            func canvasPoint(_ t: CGFloat) -> CGPoint {
                let screen = CGPoint(
                    x: edge.point.x + direction.x * t + edge.normal.x * meanDistance,
                    y: edge.point.y + direction.y * t + edge.normal.y * meanDistance
                )
                return CGPoint(x: (screen.x + offset.x) / zoom, y: (screen.y + offset.y) / zoom)
            }
            var after = before
            after.strokes[after.strokes.count - 1] = ShapeRecognizer.makeStroke(
                through: [canvasPoint(minAlong), canvasPoint(maxAlong)],
                like: stroke
            )
            setDrawing(after, undoingTo: before)
            return
        }
    }

    private func setDrawing(_ drawing: PKDrawing, undoingTo previous: PKDrawing) {
        isReplacingDrawing = true
        canvasView.drawing = drawing
        isReplacingDrawing = false
        canvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.setDrawing(previous, undoingTo: drawing)
        }
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateVisiblePages()
        updatePullIndicator()
        layoutAddPageButton()
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateContentSize()
        updateVisiblePages()
        layoutAddPageButton()
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        textOverlay.updateResolution(scale * (window?.screen.scale ?? 2))
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dragStartPageIndex = currentPageIndex
        haptics.prepare()
    }

    /// Side by side and zoomed out, pages snap into place one at a time.
    func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        guard layout.axis == .horizontal, !isBoard, canvasView.zoomScale <= fitScale * 1.02, !isPullArmed else { return }
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

/// A dashed "+ Add Page" button that sits after the last page.
private final class AddPageButton: UIButton {
    private let dashes = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "plus", withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold))
        configuration.imagePadding = 8
        configuration.attributedTitle = AttributedString("Add Page", attributes: AttributeContainer([.font: UIFont.systemFont(ofSize: 15, weight: .semibold)]))
        configuration.baseForegroundColor = Palette.inkSecondary
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 22, bottom: 12, trailing: 22)
        self.configuration = configuration
        dashes.fillColor = Palette.deskRaised.withAlphaComponent(0.6).cgColor
        dashes.strokeColor = Palette.inkSecondary.withAlphaComponent(0.5).cgColor
        dashes.lineWidth = 1.5
        dashes.lineDashPattern = [6, 5]
        layer.insertSublayer(dashes, at: 0)
        accessibilityLabel = "Add Page"
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashes.frame = bounds
        dashes.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), cornerRadius: bounds.height / 2).cgPath
    }

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: 0.15) {
                self.transform = self.isHighlighted ? CGAffineTransform(scaleX: 0.95, y: 0.95) : .identity
            }
        }
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
