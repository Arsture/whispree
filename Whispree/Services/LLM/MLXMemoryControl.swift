import Foundation
import MLX

enum MLXMemoryControl {
    /// Keep MLX's reusable Metal buffer cache bounded for a long-running menu bar app.
    ///
    /// MLX defaults the cache limit from the global memory limit, which can leave
    /// multi-GB IOAccelerator/Metal footprint behind after local inference. The
    /// model weights still require their active memory while a local provider is
    /// loaded; this limit only controls idle reusable buffers.
    static let interactiveCacheLimitBytes = 256 * 1024 * 1024

    static func configureInteractiveCacheLimit() {
        Memory.cacheLimit = interactiveCacheLimitBytes
    }

    static func releaseCachedBuffers() {
        configureInteractiveCacheLimit()
        Memory.clearCache()
    }
}
