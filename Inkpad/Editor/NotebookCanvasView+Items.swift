//
//  NotebookCanvasView+Items.swift
//  Inkpad
//

import UIKit
import PencilKit

/// Finger interaction with sticky notes, shapes, photos and graphs:
/// tap to select, drag to move, the corner handle to resize, and the action
/// bar for colour, edit, duplicate, bring to front and delete.
extension NotebookCanvasView: UIGestureRecognizerDelegate {
    func setUpItemInteraction() {
        let direct = [NSNumber(value: UITouch.TouchType.direct.rawValue)]

        itemDoubleTap.numberOfTapsRequired = 2
        itemDoubleTap.allowedTouchTypes = direct
        itemDoubleTap.cancelsTouchesInView = false
        itemDoubleTap.addTarget(self, action: #selector(handleItemDoubleTap))
        canvasView.addGestureRecognizer(itemDoubleTap)

        itemTap.allowedTouchTypes = direct
        itemTap.cancelsTouchesInView = false
        itemTap.require(toFail: itemDoubleTap)
        itemTap.addTarget(self, action: #selector(handleItemTap))
        canvasView.addGestureRecognizer(itemTap)

        itemPan.allowedTouchTypes = direct
        itemPan.maximumNumberOfTouches = 1
        itemPan.delegate = self
        itemPan.addTarget(self, action: #selector(handleItemPan))
        canvasView.addGestureRecognizer(itemPan)
        // Dragging an item moves it; dragging empty space scrolls.
        canvasView.panGestureRecognizer.require(toFail: itemPan)

        selectionChrome.onDelete = { [weak self] in
            guard let self, let id = selectedItemID else { return }
            selectItem(nil)
            commitItems(itemsOverlay.items.filter { $0.id != id })
        }
        selectionChrome.onDuplicate = { [weak self] in
            guard let self, var copy = selectedItem else { return }
            copy.id = UUID()
            copy.x += 28
            copy.y += 28
            commitItems(itemsOverlay.items + [copy])
            selectItem(copy.id)
        }
        selectionChrome.onBringToFront = { [weak self] in
            guard let self, let item = selectedItem else { return }
            commitItems(itemsOverlay.items.filter { $0.id != item.id } + [item])
        }
        selectionChrome.onColor = { [weak self] hex in
            guard let self, var item = selectedItem else { return }
            item.colorHex = hex
            replaceItem(item)
        }
        selectionChrome.onEdit = { [weak self] in
            guard let self, let item = selectedItem else { return }
            onEditItem?(item)
        }
        selectionChrome.onResize = { [weak self] translation, state in
            self?.resizeSelectedItem(by: translation, state: state)
        }
    }

    var selectedItem: BoardItem? {
        selectedItemID.flatMap { id in itemsOverlay.items.first { $0.id == id } }
    }

    func setItemsInteractive(_ isInteractive: Bool) {
        guard itemPan.isEnabled != isInteractive else { return }
        itemPan.isEnabled = isInteractive
        itemTap.isEnabled = isInteractive
        itemDoubleTap.isEnabled = isInteractive
        if !isInteractive {
            selectItem(nil)
        }
    }

    func selectItem(_ id: UUID?) {
        selectedItemID = id
        guard let item = selectedItem else {
            selectionChrome.isHidden = true
            return
        }
        selectionChrome.configure(for: item)
        selectionChrome.isHidden = false
        layoutSelection()
    }

    func layoutSelection() {
        guard let item = selectedItem else { return }
        selectionChrome.place(around: itemsOverlay.convert(item.frame, to: self))
    }

    // MARK: - Editing

    /// Applies a new set of items, undoably, and reports them for saving.
    func commitItems(_ newItems: [BoardItem], undoingTo previous: [BoardItem]? = nil) {
        let before = previous ?? itemsOverlay.items
        itemsOverlay.setItems(newItems)
        onItemsChanged?(newItems)
        layoutSelection()
        canvasView.undoManager?.registerUndo(withTarget: self) { target in
            target.selectItem(nil)
            target.commitItems(before, undoingTo: newItems)
        }
    }

    func replaceItem(_ item: BoardItem) {
        commitItems(itemsOverlay.items.map { $0.id == item.id ? item : $0 })
    }

    /// Adds an item in the middle of what's on screen (on the current page in
    /// notebooks), and returns it as placed.
    @discardableResult
    func insertItem(_ item: BoardItem) -> BoardItem {
        var item = item
        var center = visibleContentCenter
        if !isBoard, layout.frames.indices.contains(currentPageIndex) {
            let page = layout.frames[currentPageIndex].insetBy(dx: item.width / 2 + 12, dy: item.height / 2 + 12)
            if !page.isNull {
                center = CGPoint(x: min(max(center.x, page.minX), page.maxX), y: min(max(center.y, page.minY), page.maxY))
            }
        }
        item.x = center.x - item.width / 2
        item.y = center.y - item.height / 2
        commitItems(itemsOverlay.items + [item])
        selectItem(item.id)
        haptics.impactOccurred(intensity: 0.6)
        return item
    }

    var visibleContentCenter: CGPoint {
        let zoom = canvasView.zoomScale
        let offset = canvasView.contentOffset
        return CGPoint(
            x: (offset.x + bounds.width / 2) / zoom,
            y: (offset.y + (bounds.height + topInset) / 2) / zoom
        )
    }

    private func resizeSelectedItem(by translation: CGPoint, state: UIGestureRecognizer.State) {
        guard var item = selectedItem else { return }
        if state == .began {
            itemsBeforeEdit = itemsOverlay.items
        }
        let zoom = canvasView.zoomScale
        var width = item.width + translation.x / zoom
        var height = item.height + translation.y / zoom
        if item.kind == .image || item.kind == .sticky {
            // Photos and notes keep their proportions.
            let ratio = item.height / max(item.width, 1)
            width = max(width, 60)
            height = width * ratio
        }
        item.width = max(width, 40)
        item.height = max(height, 40)
        if state == .ended || state == .cancelled {
            let before = itemsBeforeEdit
            itemsBeforeEdit = nil
            commitItems(itemsOverlay.items.map { $0.id == item.id ? item : $0 }, undoingTo: before)
        } else {
            liveUpdate(item)
        }
    }

    /// Updates an item on screen while dragging, committing only at the end.
    private func liveUpdate(_ item: BoardItem) {
        itemsOverlay.setItems(itemsOverlay.items.map { $0.id == item.id ? item : $0 })
        layoutSelection()
    }

    // MARK: - Gestures

    @objc private func handleItemTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: itemsOverlay)
        selectItem(itemsOverlay.item(at: point)?.id)
    }

    @objc private func handleItemDoubleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: itemsOverlay)
        guard let item = itemsOverlay.item(at: point), item.kind == .sticky || item.kind == .graph else { return }
        selectItem(item.id)
        onEditItem?(item)
    }

    @objc private func handleItemPan(_ recognizer: UIPanGestureRecognizer) {
        guard var item = selectedItem else { return }
        switch recognizer.state {
        case .began:
            itemsBeforeEdit = itemsOverlay.items
        case .changed:
            let translation = recognizer.translation(in: itemsOverlay)
            recognizer.setTranslation(.zero, in: itemsOverlay)
            item.x += translation.x
            item.y += translation.y
            liveUpdate(item)
        case .ended, .cancelled:
            let before = itemsBeforeEdit
            itemsBeforeEdit = nil
            commitItems(itemsOverlay.items, undoingTo: before)
        default:
            break
        }
    }

    /// Item drags only start on an item; anywhere else the page scrolls.
    override func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer === itemPan else { return super.gestureRecognizerShouldBegin(recognizer) }
        guard let item = itemsOverlay.item(at: recognizer.location(in: itemsOverlay)) else { return false }
        if selectedItemID != item.id {
            selectItem(item.id)
        }
        return true
    }

    // MARK: - Zoom

    /// Fits all ink, text and items on screen (canvas boards).
    func zoomToFitContent() {
        var content = canvasView.drawing.bounds
        content = textOverlay.boxes.reduce(content) { $0.union($1.frame) }
        content = itemsOverlay.items.reduce(content) { $0.union($1.frame) }
        guard !content.isNull, !content.isEmpty else { return }
        canvasView.zoom(to: content.insetBy(dx: -60, dy: -60), animated: true)
    }
}
