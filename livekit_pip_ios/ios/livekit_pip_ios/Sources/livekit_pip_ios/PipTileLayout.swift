import CoreGraphics

/// Ordering and sizing of the PiP tiles. Pure, so the rules read in one place.
enum PipTileLayout {

    struct Tile: Equatable {
        let isLocal: Bool
        /// Width / height of what the tile shows.
        let aspect: CGFloat
    }

    /// Shape of a tile with no video: a portrait phone camera.
    static let noVideoAspect: CGFloat = 9 / 16

    /// The system snaps the PiP window to its own sizes; only the shape matters.
    static let windowHeight: CGFloat = 180

    /// Window shape before any participant arrives; must never be zero.
    static let emptyWindowSize = CGSize(width: 320, height: 180)

    /// Indices of `tiles`, left to right. A single landscape tile goes left;
    /// otherwise the local tile does.
    static func order(_ tiles: [Tile]) -> [Int] {
        let indices = Array(tiles.indices)
        let landscape = indices.filter { aspect(of: tiles[$0]) > 1 }
        if landscape.count == 1 {
            return landscape + indices.filter { $0 != landscape[0] }
        }
        return indices.filter { tiles[$0].isLocal } + indices.filter { !tiles[$0].isLocal }
    }

    /// Frames for `tiles`, indexed like `tiles`: full height, widths in
    /// proportion to each tile's shape.
    static func frames(_ tiles: [Tile], in bounds: CGRect) -> [CGRect] {
        let total = tiles.reduce(0) { $0 + aspect(of: $1) }
        guard total > 0 else { return [] }
        var frames = Array(repeating: CGRect.zero, count: tiles.count)
        var x = bounds.minX
        for index in order(tiles) {
            let width = bounds.width * aspect(of: tiles[index]) / total
            frames[index] = CGRect(x: x, y: bounds.minY, width: width, height: bounds.height)
            x += width
        }
        return frames
    }

    static func windowSize(_ tiles: [Tile]) -> CGSize {
        let total = tiles.reduce(0) { $0 + aspect(of: $1) }
        guard total > 0 else { return emptyWindowSize }
        return CGSize(width: (windowHeight * total).rounded(), height: windowHeight)
    }

    private static func aspect(of tile: Tile) -> CGFloat {
        tile.aspect.isFinite && tile.aspect > 0 ? tile.aspect : noVideoAspect
    }
}
