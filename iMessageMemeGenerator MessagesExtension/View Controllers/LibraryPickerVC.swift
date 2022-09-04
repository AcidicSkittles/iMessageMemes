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
        configure.numberOfColumn = UIView.itemsPerRow()
        configure.autoPlay = false
        configure.doneTitle = ""
        configure.allowedAlbumCloudShared = true
        configure.singleSelectedMode = true
        self.configure = configure
        self.delegate = self
        self.logDelegate = self
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
    
    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        super.collectionView(collectionView, didSelectItemAt: indexPath)

        guard let cell = self.collectionView.cellForItem(at: indexPath) as? TLPhotoCollectionViewCell else { return }
        
        if self.selectedAssets.count == 1 {
            self.doneButtonTap()
            // deselect
            toggleSelection(for: cell, at: indexPath)
        }
    }
    
    override func doneButtonTap() {
        guard !MessagesViewController.shared.isTransitioning else { return }
        
        if let customAsset: TLPHAsset = self.selectedAssets.first {
            
            if customAsset.type == .photo {
                let asset: PHAsset = customAsset.phAsset!
                
                let options: PHImageRequestOptions = PHImageRequestOptions()
                options.version = .current
                options.isNetworkAccessAllowed = true
                options.progressHandler = { (progress, _, _, _) in
                    print("progressHandler progress \(progress)")
                    self.loadingView.isHidden = false
                }
                
                PHImageManager.default().requestImageData(for: asset, options: options) { (data: Data?, _, orientation: UIImage.Orientation, _) in
                    
                    if data != nil {
                        if let image: UIImage = UIImage(data: data!) {
                            if orientation != .up {
                                self.loadingView.isHidden = false
                                
                                DispatchQueue.global(qos: .userInitiated).async {
                                    let upRightImage = UIImage.imageRedrawnUpright(image: image)
                                    
                                    let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC()
                                    lineBoxInput.delegate = self
                                    lineBoxInput.selectionImageData = upRightImage.pngData()
                                    
                                    DispatchQueue.main.async {
                                        self.loadingView.isHidden = true
                                        
                                        MessagesViewController.shared.requestPresentationStyle(.expanded)
                                        
                                        self.present(lineBoxInput, animated: true)
                                    }
                                }
                            } else {
                                let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC()
                                lineBoxInput.delegate = self
                                lineBoxInput.selectionImageData = data
                                
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
                    } else {
                        DispatchQueue.main.async {
                            self.loadingView.isHidden = true
                            self.show(alert: "UNSUPPORTED_FILE".localized)
                        }
                    }
                }
            } else if customAsset.type == .video {
                self.loadingView.isHidden = false
                
                let asset: PHAsset = customAsset.phAsset!
                
                let options: PHVideoRequestOptions = PHVideoRequestOptions()
                options.version = .current
                options.isNetworkAccessAllowed = true
                options.progressHandler = { (progress, _, _, _) in
                    print("progressHandler progress \(progress)")
                    self.loadingView.isHidden = false
                }
                
                PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { (avAsset: AVAsset?, _, _) in
                    
                    let completionHandler: (URL) -> Void = { videoPath in
                        
                        let lineBoxInput: MultiLineInputBoxVC = MultiLineInputBoxVC()
                        lineBoxInput.delegate = self
                        lineBoxInput.selectionVideoPath = videoPath
                        
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
                    } else if let avCompositionAsset = avAsset as? AVComposition {
                        
                        if avCompositionAsset.tracks.count > 1 {
                            let tmpDirURL: URL = URL.init(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                            let videoPath: URL = tmpDirURL.appendingPathComponent("temp").appendingPathExtension("mp4")
                            
                            let exporter = AVAssetExportSession(asset: avCompositionAsset, presetName: AVAssetExportPresetHighestQuality)
                            exporter!.outputURL = videoPath
                            exporter!.outputFileType = AVFileType.mp4
                            exporter!.shouldOptimizeForNetworkUse = true
                        
                            exporter!.exportAsynchronously {
                                DispatchQueue.main.async {
                                    self.loadingView.isHidden = true
                                    completionHandler(exporter!.outputURL!)
                                }
                            }
                        } else {
                            DispatchQueue.main.async {
                                self.loadingView.isHidden = true
                                self.show(alert: "Unsupported file type.")
                            }
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.loadingView.isHidden = true
                            self.show(alert: "Unsupported file type.")
                        }
                    }
                }
            }
        }
    }
}

extension LibraryPickerVC: TLPhotosPickerLogDelegate {
    func selectedCameraCell(picker: TLPhotosPickerViewController) {
        MessagesViewController.shared.requestPresentationStyle(.expanded)
    }
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
    func finishedCaptionedImagePath(_ captionedImagePath: URL) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.composeMessage(with: captionedImagePath)
    }
    
    func finishedCaptionedVideoPath(_ captionedVideoPath: URL) {
        self.loadingView.isHidden = true
        MessagesViewController.shared.composeMessage(with: captionedVideoPath)
    }
}
