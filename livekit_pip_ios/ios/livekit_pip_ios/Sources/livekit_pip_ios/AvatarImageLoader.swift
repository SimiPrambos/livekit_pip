import UIKit

/// Fetches and caches avatar images for PiP tiles.
///
/// Avatars identify people, so URLs are never logged and only HTTPS is
/// fetched. Everything except the network call runs on the main thread.
final class AvatarImageLoader {

    static let shared = AvatarImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var pending: [URL: [(UIImage?) -> Void]] = [:]

    /// Calls `completion` on the main thread with the image, or nil on failure.
    func load(_ url: URL, completion: @escaping (UIImage?) -> Void) {
        guard url.scheme?.lowercased() == "https" else {
            completion(nil)
            return
        }
        if let image = cache.object(forKey: url as NSURL) {
            completion(image)
            return
        }
        if pending[url] != nil {
            pending[url]?.append(completion)
            return
        }
        pending[url] = [completion]
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            let image = data.flatMap(UIImage.init(data:))
            DispatchQueue.main.async {
                guard let self else { return }
                if let image { self.cache.setObject(image, forKey: url as NSURL) }
                let completions = self.pending.removeValue(forKey: url) ?? []
                completions.forEach { $0(image) }
            }
        }.resume()
    }
}
