//
//  PageSlotView.swift
//  Inkpad
//

import UIKit

/// What sits behind the ink on a page.
nonisolated enum PageBackground {
    case paper(PaperStyle, PaperColor)
    case pdf(CGPDFPage)
}

/// Draws a page's background in tiles on background threads, re-rendering at
/// higher detail as you zoom, so lines and PDF text stay sharp.
nonisolated final class PageTiledLayer: CATiledLayer {
    var background: PageBackground = .paper(.blank, .white)

    override class func fadeDuration() -> CFTimeInterval { 0.05 }

    override init() {
        super.init()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? PageTiledLayer {
            background = other.background
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func draw(in context: CGContext) {
        switch background {
        case .paper(let style, let color):
            PaperRenderer.draw(style, color: color, in: context, size: bounds.size)
        case .pdf(let page):
            PageRenderer.drawPDFPage(page, size: bounds.size, in: context)
        }
    }
}

private final class PageTileView: UIView {
    override class var layerClass: AnyClass { PageTiledLayer.self }
}

/// One page on the desk: a soft shadow with the tiled page on top.
final class PageSlotView: UIView {
    init(frame: CGRect, background: PageBackground) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowRadius = 10
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowPath = UIBezierPath(rect: bounds).cgPath

        let tileView = PageTileView(frame: bounds)
        if let tiledLayer = tileView.layer as? PageTiledLayer {
            tiledLayer.background = background
            tiledLayer.tileSize = CGSize(width: 512, height: 512)
            tiledLayer.levelsOfDetail = 4
            tiledLayer.levelsOfDetailBias = 3
        }
        addSubview(tileView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
