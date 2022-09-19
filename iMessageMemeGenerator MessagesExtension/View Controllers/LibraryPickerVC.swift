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

class LibraryPickerVC: TLPhotosPickerViewController, LoadableView {
    var loadingView: LoadingView = UIView.fromNib()
    var imageCaptionGenerator: ImageMemeGeneratorProtocol?
    var videoCaptionGenerator: VideoMemeGeneratorProtocol?
    
    @objc override init() {
        super.init()
        
        self.configureUI()
        self.setupLoadingView()
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
    }
}

// MARK: - UI & UI Actions
extension LibraryPickerVC {
    private func configureUI() {
        var configure = TLPhotosPickerConfigure()
        configure.numberOfColumn = LayoutSettings.itemsPerRow
        configure.minimumLineSpacing = LayoutSettings.spacing
        configure.minimumInteritemSpacing = LayoutSettings.spacing
        configure.allowedAlbumCloudShared = true
        configure.singleSelectedMode = true
        configure.customLocalizedTitle = ["CAMERA_ROLL".localized: "CAMERA_ROLL".localized]
        configure.tapHereToChange = "TAP_TO_CHANGE".localized
        configure.cancelTitle = "CANCEL".localized
        configure.doneTitle = "DONE".localized
        configure.emptyMessage = "NO_ALBUMS".localized
        configure.selectMessage = "SELECT".localized
        configure.deselectMessage = "DESELECT".localized
        self.configure = configure
        
        self.delegate = self
        self.eventDelegate = self
    }
    
    func caption(asset: TLPHAsset) {
        guard !MessagesViewController.shared.isTransitioning, let phAsset: PHAsset = asset.phAsset else { return }
        
        switch asset.type {
        case .photo, .livePhoto:
            let options: PHImageRequestOptions = PHImageRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.progressHandler = { (progress, _, _, _) in
                print("progressHandler progress \(progress)")
                self.loadingView.isHidden = false
            }
            
            PHImageManager.default().requestImageDataAndOrientation(for: phAsset, options: options) { (data: Data?, _, _, _) in
                guard let data = data else {
                    self.loadingView.isHidden = true
                    self.show(alert: "UNSUPPORTED_FILE".localized)
                    return
                }
                
                self.selected(imageData: data)
            }
        case .video:
            self.loadingView.isHidden = false
            
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .current
            options.isNetworkAccessAllowed = true
            options.progressHandler = { (progress, _, _, _) in
                print("progressHandler progress \(progress)")
            }
            
            PHImageManager.default().requestAVAsset(forVideo: phAsset, options: options) { (avAsset: AVAsset?, _, _) in
                if let urlAsset: AVURLAsset = avAsset as? AVURLAsset {
                    DispatchQueue.main.async {
                        self.selected(videoPath: urlAsset.url)
                    }
                } else if let avCompositionAsset = avAsset as? AVComposition {
                
                    VideoHelpers.exportAsync(assetComposition: avCompositionAsset) { [unowned self] outputPath, error in
                        DispatchQueue.main.async {
                            self.loadingView.isHidden = true
                            
                            if let error = error {
                                self.show(alert: error.localizedDescription)
                            } else if let outputPath = outputPath {
                                self.selected(videoPath: outputPath)
                            } else {
                                self.show(alert: "UNSUPPORTED_FILE".localized)
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        self.loadingView.isHidden = true
                        self.show(alert: "UNSUPPORTED_FILE".localized)
                    }
                }
            }
        }
    }
    
    private func selected(imageData: Data) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.requestPresentationStyle(.expanded)
        
        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionImageData: imageData)
        lineBoxInput.delegate = self
        self.present(lineBoxInput, animated: true)
    }
    
    private func selected(videoPath: URL) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.requestPresentationStyle(.expanded)
        
        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC(withSelectionVideoPath: videoPath)
        lineBoxInput.delegate = self
        self.present(lineBoxInput, animated: true)
    }
    
    private func outputTempVideoPath(pathExtension: String) -> URL {
        let tmpDirURL: URL = URL.init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let videoPath: URL = tmpDirURL.appendingPathComponent("temp").appendingPathExtension(pathExtension)
        return videoPath
    }
}

// MARK: - TLPhotosPickerViewControllerDelegate
extension LibraryPickerVC: TLPhotosPickerViewControllerDelegate {
    func canSelectAsset(phAsset: PHAsset) -> Bool {
        return !MessagesViewController.shared.isTransitioning
    }
    
    func handleNoAlbumPermissions(picker: TLPhotosPickerViewController) {
        self.show(alert: "ENABLE_PHOTOS".localized)
    }
    
    func handleNoCameraPermissions(picker: TLPhotosPickerViewController) {
        self.show(alert: "ENABLE_CAMERA".localized)
    }
}

// MARK: - TLPhotosPickerEventDelegate
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

// MARK: - MultiLineInputBoxDelegate
extension LibraryPickerVC: MultiLineInputBoxDelegate {
    
    func add(text: String, toImageData imageData: Data) {
        self.loadingView.isHidden = false
        
        self.imageCaptionGenerator = ModernImageCaptionGenerator()
        self.imageCaptionGenerator?.delegate = self
        self.imageCaptionGenerator?.generateCaption(text, toImageData: imageData)
    }
    
    func add(text: String, toVideoAtPath videoPath: URL) {
        self.loadingView.isHidden = false
        
        self.videoCaptionGenerator = ModernVideoCaptionGenerator()
        self.videoCaptionGenerator?.delegate = self
        self.videoCaptionGenerator?.generateCaption(text, toVideoAtPath: videoPath)
    }
}

// MARK: - CaptionGeneratorDelegate
extension LibraryPickerVC: CaptionGeneratorDelegate {
    
    func finishedCaptionedMedia(atPath captionedMediaPath: URL?, withError error: Error?) {
        self.loadingView.isHidden = true
        
        if let error = error {
            self.show(alert: error.localizedDescription)
        } else if let captionedMediaPath = captionedMediaPath {
            MessagesViewController.shared.composeMessage(with: captionedMediaPath)
        }
    }
}
