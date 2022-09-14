//
//  LibraryPickerVC.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 8/31/22.
//

import UIKit
import TLPhotoPicker
import PhotosUI
import MobileCoreServices

class LibraryPickerVC: TLPhotosPickerViewController, TLPhotosPickerViewControllerDelegate, LoadableView {
    
    var loadingView: LoadingView = UIView.fromNib()
    let captionGenerator: CaptionGenerator = CaptionGenerator()
    
    @objc override init() {
        super.init()
        
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = LayoutSettings.itemsPerRow
        configure.minimumLineSpacing = LayoutSettings.spacing
        configure.minimumInteritemSpacing = LayoutSettings.spacing
        configure.allowedAlbumCloudShared = true
        configure.singleSelectedMode = true
        self.configure = configure
        self.delegate = self
        self.eventDelegate = self
        self.loadingView.frame = self.view.bounds
        self.loadingView.isHidden = true
        self.view.addSubview(self.loadingView)
        
        self.captionGenerator.delegate = self
        
        self.setupLoadingView()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
    
    func canSelectAsset(phAsset: PHAsset) -> Bool {
        return !MessagesViewController.shared.isTransitioning
    }
    
    public func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        self.show(alert: "You must enable photo album access under Settings ➡️ Privacy ➡️ Photos")
    }
    
    public func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        self.show(alert: "You must enable camera access under Settings ➡️ Privacy ➡️ Camera")
    }
}

extension LibraryPickerVC {
    func caption(asset: TLPHAsset) {
        guard !MessagesViewController.shared.isTransitioning, let phAsset: PHAsset = asset.phAsset else { return }
            
        if asset.type == .photo || asset.type == .livePhoto {
            let options: PHImageRequestOptions = PHImageRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.progressHandler = { (progress, _, _, _) in
                print("progressHandler progress \(progress)")
                self.loadingView.isHidden = false
            }
            
            PHImageManager.default().requestImageData(for: phAsset, options: options) { (data: Data?, _, orientation: UIImage.Orientation, _) in
                
                if let data = data, let image: UIImage = UIImage(data: data) {
                    if orientation != .up {
                        self.loadingView.isHidden = false
                        
                        DispatchQueue.global(qos: .userInitiated).async {
                            let upRightImage = UIImage.imageRedrawnUpright(image: image)
                            
                            if let imageData = upRightImage.pngData() {
                                let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionImageData: imageData)
                                lineBoxInput.delegate = self
                                
                                DispatchQueue.main.async {
                                    self.loadingView.isHidden = true
                                    
                                    MessagesViewController.shared.requestPresentationStyle(.expanded)
                                    
                                    self.present(lineBoxInput, animated: true)
                                }
                            } else {
                                DispatchQueue.main.async {
                                    self.loadingView.isHidden = true
                                    self.show(alert: "UNSUPPORTED_FILE".localized)
                                }
                            }
                        }
                    } else {
                        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionImageData: data)
                        lineBoxInput.delegate = self
                        
                        DispatchQueue.main.async {
                            self.loadingView.isHidden = true
                            
                            MessagesViewController.shared.requestPresentationStyle(.expanded)
                            
                            self.present(lineBoxInput, animated: true)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loadingView.isHidden = true
                        self.show(alert: "UNSUPPORTED_FILE".localized)
                    }
                }
            }
        } else if asset.type == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.progressHandler = { (progress, _, _, _) in
                print("progressHandler progress \(progress)")
                self.loadingView.isHidden = false
            }
            
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avAsset: AVAsset?, _, _) in
                
                let completionHandler: (URL) -> Void = { videoPath in
                    
                    let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionVideoPath: videoPath)
                    lineBoxInput.delegate = self
                    
                    MessagesViewController.shared.requestPresentationStyle(.expanded)
                    
                    self.present(lineBoxInput, animated: true)
                }
                
                if let urlAsset: AVURLAsset = avAsset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url
                    
                    let videoData: Data = try! Data.init(contentsOf: localVideoUrl)
                    let tmpDirURL: URL = URL.init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                    let videoPath: URL = tmpDirURL.appendingPathComponent("temp").appendingPathExtension(localVideoUrl.pathExtension)
                    try! videoData.write(to: videoPath)
                
                    DispatchQueue.main.async {
                        self.loadingView.isHidden = true
                        completionHandler(videoPath)
                    }
                } else if let avCompositionAsset = avAsset as? AVComposition,
                          let exporter = AVAssetExportSession(asset: avCompositionAsset, presetName: AVAssetExportPresetHighestQuality) {
                    
                    let tmpDirURL: URL = URL.init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                    let videoPath: URL = tmpDirURL.appendingPathComponent("temp").appendingPathExtension("mp4")
                    
                    exporter.outputURL = videoPath
                    exporter.outputFileType = AVFileType.mp4
                    exporter.shouldOptimizeForNetworkUse = true
                
                    exporter.exportAsynchronously {
                        DispatchQueue.main.async {
                            self.loadingView.isHidden = true
                            completionHandler(videoPath)
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loadingView.isHidden = true
                        self.show(alert: "UNSUPPORTED_FILE".localized)
                    }
                }
            }
        } else {
            self.loadingView.isHidden = true
            self.show(alert: "UNSUPPORTED_FILE".localized)
        }
    }
}

extension LibraryPickerVC: TLPhotosPickerEventDelegate {
    func selectedCameraCell(picker: TLPhotosPickerViewController) {
        MessagesViewController.shared.requestPresentationStyle(.expanded)
    }
    
    // swiftlint:disable identifier_name
    func singleSelectedAsset(asset: TLPHAsset, picker: TLPhotosPickerViewController, at: Int) {
        self.caption(asset: asset)
    }
    // swiftlint:enable identifier_name
}

extension LibraryPickerVC: MultiLineInputBoxDelegate {
    func addText(text: String, toImageData imageData: Data) {
        self.loadingView.isHidden = false
        self.captionGenerator.generateCaption(text, toImageData: imageData)
    }
    
    func addText(text: String, toVideoAtPath videoPath: URL) {
        self.loadingView.isHidden = false
        self.captionGenerator.generateCaption(text, toVideoAtPath: videoPath)
    }
}

extension LibraryPickerVC: CaptionGeneratorDelegate {
    func finishedCaptionedImage(atPath captionedImagePath: URL) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.composeMessage(with: captionedImagePath)
    }
    
    func finishedCaptionedVideo(atPath captionedVideoPath: URL?, withError error: Error?) {
        self.loadingView.isHidden = true
        
        if let error = error {
            self.show(alert: error.localizedDescription)
        } else if let captionedVideoPath = captionedVideoPath {
            MessagesViewController.shared.composeMessage(with: captionedVideoPath)
        }
    }
}
