//
//  VideoHelpers.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/17/22.
//

import Foundation
import AVKit
import UIKit

@objc class VideoHelpers: NSObject {
    private override init() {}
    
    @objc class func videoOrientation(fromVideoTrack videoTrack: AVAssetTrack) -> UIImage.Orientation {
        var videoAssetOrientation: UIImage.Orientation = .up
        let videoTransform: CGAffineTransform = videoTrack.preferredTransform
        if videoTransform.a == 0 && videoTransform.b == 1.0 && videoTransform.c == -1.0 && videoTransform.d == 0 {
            videoAssetOrientation = .left
        } else if videoTransform.a == 0 && videoTransform.b == -1.0 && videoTransform.c == 1.0 && videoTransform.d == 0 {
            videoAssetOrientation =  .right
        } else if videoTransform.a == 1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == 1.0 {
            videoAssetOrientation =  .up
        } else if videoTransform.a == -1.0 && videoTransform.b == 0 && videoTransform.c == 0 && videoTransform.d == -1.0 {
            videoAssetOrientation = .down
        }
        
        return videoAssetOrientation
    }
    
    /// Upright video size that takes into account the orientation.
    /// - Parameter videoTrack: The video track to analyze.
    /// - Returns: A size mutated to fit the underlying video orientation into the upright position.
    @objc class func uprightVideoSize(fromVideoTrack videoTrack: AVAssetTrack) -> CGSize {
        let naturalVideoSize = videoTrack.naturalSize
        let videoOrientation = videoOrientation(fromVideoTrack: videoTrack)
        switch videoOrientation {
        case .left, .right:
            return CGSize(width: naturalVideoSize.height, height: naturalVideoSize.width)
        default:
            return naturalVideoSize
        }
    }
    
    /// Retrieve the correct upright and upscaled transformations for a video.
    ///
    /// Videos can sometimes be transformed based on how the camera is held,
    /// despite the raw video frames being encoded as sideways. If the camera
    /// was held landscape, a transform can be applied to the frames.
    /// We need to remove this transform and re-encode upright in correct space.
    /// - Parameters:
    ///   - videoTrack: The video track to analyze.
    ///   - outputVideoSize: The desired output video size.
    /// - Returns: A transform containing upright rotations - if any are needed -
    /// and a scale transform if the original video size  does not match the output size.
    @objc class func uprightAndScaledVideoTransform(forVideoTrack videoTrack: AVAssetTrack, outputVideoSize: CGSize) -> CGAffineTransform {
        let originalUprightVideoSize: CGSize = uprightVideoSize(fromVideoTrack: videoTrack)
        var transformations: CGAffineTransform = videoTrack.preferredTransform
        
        // scale our video to the desired output size
        let outputWidthRatio = outputVideoSize.width / originalUprightVideoSize.width
        let outputHeightRatio = outputVideoSize.height / originalUprightVideoSize.height
        transformations = transformations.concatenating(CGAffineTransform(scaleX: outputWidthRatio, y: outputHeightRatio))
        
        return transformations
    }
    
    /// Initializes a composition to the recommended helpful settings by adding video and audio tracks if found.
    /// - Parameter asset: The source asset to extrapolate video and audio tracks from.
    /// - Returns: A composition if successful, nil if an error likely occured.
    @objc class func defaultAVMutableComposition(fromAsset asset: AVURLAsset) -> AVMutableComposition? {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        
        let mixComposition: AVMutableComposition = AVMutableComposition.init()
        guard let compositionVideoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { return nil }

        let videoTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: videoTrack.timeRange.duration)
        do {
            try compositionVideoTrack.insertTimeRange(videoTimeRange, of: videoTrack, at: CMTime.zero)
        } catch { return nil }
        
        // add audio track if it is present, not all videos have audio
        if let audioTrack = asset.tracks(withMediaType: .audio).first,
           let compositionAudioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            do {
                try compositionAudioTrack.insertTimeRange(videoTimeRange, of: audioTrack, at: CMTime.zero)
            } catch { return nil }
        }
        
        return mixComposition
    }
    
    /// Initializes a video composition to the default helpful render settings and layer instructions.
    /// - Parameters:
    ///   - asset: The source asset to extrapolate video tracks from.
    ///   - sourceComposition: source mutable composition containing the mutable video composition tracks for layer instructions.
    ///   - outputRenderSize: The output file render size.
    /// - Returns: Video composition containing layer instructions and render settings.
    @objc class func defaultAVMutableVideoComposition(fromAsset asset: AVURLAsset, sourceComposition: AVMutableComposition, outputRenderSize: CGSize) -> AVMutableVideoComposition? {
        guard let videoTrack = asset.tracks(withMediaType: .video).first else { return nil }
        
        let videoTimeRange = CMTimeRangeMake(start: CMTime.zero, duration: videoTrack.timeRange.duration)
        
        // create video layer instructions with transforms
        let memeInstruction: AVMutableVideoCompositionInstruction = AVMutableVideoCompositionInstruction.init()
        memeInstruction.timeRange = videoTimeRange
        
        guard let compositionVideoTrack: AVMutableCompositionTrack = sourceComposition.tracks(withMediaType: .video).first else { return nil }
        
        let layerInstruction = AVMutableVideoCompositionLayerInstruction.init(assetTrack: compositionVideoTrack)
        
        let transforms = VideoHelpers.uprightAndScaledVideoTransform(forVideoTrack: videoTrack, outputVideoSize: outputRenderSize)
        layerInstruction.setTransform(transforms, at: CMTime.zero)
        // remove any video opacity
        layerInstruction.setOpacity(1.0, at: CMTime.zero)
        memeInstruction.layerInstructions = [layerInstruction]
        
        // add all of our captions and layers to a composition
        let memeComposition: AVMutableVideoComposition = AVMutableVideoComposition.init()
        memeComposition.renderSize = outputRenderSize
        memeComposition.frameDuration = CMTimeMake(value: 1, timescale: Int32(videoTrack.nominalFrameRate))
        memeComposition.instructions = [memeInstruction]
        
        return memeComposition
    }
    
    @objc class func exportAsync(assetComposition: AVComposition, videoComposition: AVVideoComposition? = nil, completion: @escaping ((URL?, Error?) -> Void)) {
        let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let outputVideoPath = tmpDirURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("mp4")
        
        if let assetExport = AVAssetExportSession(asset: assetComposition, presetName: AVAssetExportPresetHighestQuality) {
            assetExport.outputFileType = .mp4
            assetExport.outputURL = outputVideoPath
            assetExport.videoComposition = videoComposition
            assetExport.shouldOptimizeForNetworkUse = true
        
            try? FileManager.default.removeItem(atPath: outputVideoPath.path)
            
            assetExport.exportAsynchronously {
                completion(outputVideoPath, assetExport.error)
            }
        } else {
            completion(nil, NSError(domain: "", code: 1, userInfo: [NSLocalizedDescriptionKey: "UNSUPPORTED_FILE".localized]))
        }
    }
}
