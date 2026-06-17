import WebRTC

/// Isolates all flutter_webrtc internals to a single file.
///
/// If flutter_webrtc changes its registry API, only this file needs updating.
protocol NativeTrackResolver {
    func resolveVideoTrack(trackId: String) -> RTCVideoTrack?
}

/// Accesses flutter_webrtc's internal track registry via the shared plugin.
class FlutterWebRTCTrackResolver: NativeTrackResolver {
    func resolveVideoTrack(trackId: String) -> RTCVideoTrack? {
        // flutter_webrtc stores tracks in the plugin's localTracks / remoteTracks dictionaries.
        // Access via Objective-C bridging since FlutterWebRTCPlugin is an ObjC class.
        guard
            let pluginClass = NSClassFromString("FlutterWebRTCPlugin") as? NSObject.Type,
            let plugin = pluginClass.value(forKey: "sharedPlugin") as? NSObject
        else {
            print("[livekit_pip] NativeTrackResolver: FlutterWebRTCPlugin not found — is flutter_webrtc initialized?")
            return nil
        }
        if let tracks = plugin.value(forKey: "localTracks") as? [String: RTCVideoTrack],
           let track = tracks[trackId] {
            return track
        }
        if let tracks = plugin.value(forKey: "remoteTracks") as? [String: RTCVideoTrack],
           let track = tracks[trackId] {
            return track
        }
        return nil
    }
}
