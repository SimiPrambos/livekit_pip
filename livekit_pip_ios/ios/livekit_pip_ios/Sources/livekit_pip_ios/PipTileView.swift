import UIKit
import WebRTC

/// One participant in the PiP window: their video, or their avatar while the
/// camera is off, plus a badge while their microphone is muted.
///
/// A muted or interrupted camera must never leave the last frame on screen:
/// the display layer keeps it, which reads as "still on camera".
final class PipTileView: UIView {

    private(set) var participant: PipParticipant?

    /// Called on the main thread when the shape this tile wants changes.
    var onAspectChanged: (() -> Void)?

    var isMirrored = false {
        didSet {
            renderer.transform = isMirrored ? CGAffineTransform(scaleX: -1, y: 1) : .identity
        }
    }

    /// Set for the local tile while iOS has paused the camera.
    var isCameraInterrupted = false {
        didSet {
            guard isCameraInterrupted != oldValue else { return }
            updateContent()
        }
    }

    /// Width / height of what the tile shows.
    var aspect: CGFloat {
        guard showsVideo, let videoSize, videoSize.height > 0 else {
            return PipTileLayout.noVideoAspect
        }
        return videoSize.width / videoSize.height
    }

    private(set) var track: RTCVideoTrack?

    private let sizeObserver = PipTileSizeObserver()
    private let renderer: PipVideoRenderer
    private let avatarView = UIImageView()
    private let initialsLabel = UILabel()
    private let micBadge = UIView()
    private var videoSize: CGSize?
    private var loadingAvatarURL: URL?
    /// The renderer only gets frames inside the PiP window, so without this
    /// the first PiP opens before any tile knows its shape.
    private var sizeProbe: PipFrameSizeProbe?

    private var showsVideo: Bool { track != nil && !isCameraInterrupted }

    override init(frame: CGRect) {
        renderer = PipVideoRenderer(windowSizePolicy: sizeObserver)
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.12, alpha: 1)
        clipsToBounds = true

        initialsLabel.textColor = .white
        initialsLabel.textAlignment = .center
        initialsLabel.backgroundColor = UIColor(white: 0.3, alpha: 1)
        initialsLabel.clipsToBounds = true

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true

        micBadge.backgroundColor = UIColor(white: 0, alpha: 0.45)
        let micIcon = UIImageView(image: UIImage(systemName: "mic.slash.fill"))
        micIcon.tintColor = .white
        micIcon.contentMode = .scaleAspectFit
        micIcon.frame = CGRect(x: 6, y: 6, width: 14, height: 14)
        micBadge.addSubview(micIcon)

        [renderer, initialsLabel, avatarView, micBadge].forEach(addSubview)
        sizeObserver.onChange = { [weak self] size in self?.updateVideoSize(size) }
        updateContent()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        sizeProbe?.stop()
    }

    /// Shows `participant`, or clears the tile with `nil`. The track is only
    /// resolved again when its id changes.
    func apply(_ participant: PipParticipant?, resolveTrack: (String) -> RTCVideoTrack?) {
        let previous = self.participant
        self.participant = participant
        if participant?.videoTrackId != previous?.videoTrackId || participant == nil {
            track = participant?.videoTrackId.flatMap(resolveTrack)
            videoSize = nil
        }
        initialsLabel.text = Self.initials(of: participant?.displayName ?? "")
        if participant?.avatarUrl != previous?.avatarUrl || participant == nil {
            loadAvatar(participant?.avatarUrl)
        }
        updateContent()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateSizeProbe()
    }

    /// Re-primes frame delivery once the PiP window owns the display layer.
    func resumeStreaming() {
        renderer.resumeStreaming()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        renderer.frame = bounds
        let diameter = (min(bounds.width, bounds.height) * 0.4).rounded()
        let circle = CGRect(
            x: bounds.midX - diameter / 2,
            y: bounds.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        avatarView.frame = circle
        initialsLabel.frame = circle
        avatarView.layer.cornerRadius = diameter / 2
        initialsLabel.layer.cornerRadius = diameter / 2
        initialsLabel.font = .systemFont(ofSize: diameter * 0.38, weight: .semibold)
        let badge: CGFloat = 26
        micBadge.frame = CGRect(
            x: bounds.maxX - badge - 8,
            y: bounds.maxY - badge - 8,
            width: badge,
            height: badge
        )
        micBadge.layer.cornerRadius = badge / 2
    }

    // MARK: - Private

    private func updateContent() {
        let video = showsVideo
        // Unbinding stops frame delivery, so a hidden renderer costs nothing.
        renderer.track = video ? track : nil
        renderer.isHidden = !video
        avatarView.isHidden = video || avatarView.image == nil
        initialsLabel.isHidden = video || avatarView.image != nil
        micBadge.isHidden = !(participant?.isMicMuted ?? false)
        updateSizeProbe()
        onAspectChanged?()
    }

    private func updateVideoSize(_ size: CGSize) {
        guard videoSize != size else { return }
        videoSize = size
        onAspectChanged?()
    }

    private func updateSizeProbe() {
        let target = window == nil && showsVideo ? track : nil
        guard target !== sizeProbe?.track else { return }
        sizeProbe?.stop()
        sizeProbe = target.map { track in
            let probe = PipFrameSizeProbe(track: track)
            probe.onSize = { [weak self, weak probe] size in
                guard let self, let probe, self.sizeProbe === probe else { return }
                self.updateVideoSize(size)
            }
            return probe
        }
    }

    private func loadAvatar(_ address: String?) {
        avatarView.image = nil
        guard let address, let url = URL(string: address) else {
            loadingAvatarURL = nil
            return
        }
        loadingAvatarURL = url
        AvatarImageLoader.shared.load(url) { [weak self] image in
            // A newer participant may have replaced the one this was for.
            guard let self, self.loadingAvatarURL == url else { return }
            self.avatarView.image = image
            self.updateContent()
        }
    }

    private static func initials(of name: String) -> String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap { $0.first.map(String.init) }
            .joined()
            .uppercased()
    }
}
