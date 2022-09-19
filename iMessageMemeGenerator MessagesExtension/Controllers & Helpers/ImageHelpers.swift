//
//  ImageHelpers.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/18/22.
//

import UIKit
import ImageIO

@objc class ImageHelpers: NSObject {
    private override init() {}
    
    @objc class func uprightImageSize(fromImage image: UIImage) -> CGSize {
        let imageSize = image.size
        let imageOrientation = image.imageOrientation
        switch imageOrientation {
        case .left, .right:
            return CGSize(width: imageSize.height, height: imageSize.width)
        default:
            return imageSize
        }
    }
    
    @objc class func uprightImageSize(fromImageData imageData: NSData) -> CGSize {
        guard let source: CGImageSource = CGImageSourceCreateWithData(imageData, nil) else { return .zero }
        guard let properties: [CFString: Any] = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return .zero }

        if let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let height = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            
            let orientationValue: CGImagePropertyOrientation = properties[kCGImagePropertyOrientation] as? CGImagePropertyOrientation ?? .up
            switch orientationValue {
            case .left, .right:
                return CGSize(width: height, height: width)
            default:
                return CGSize(width: width, height: height)
            }
        } else {
            return .zero
        }
    }
    
    /// Get the type of the image container
    /// - Parameter imageData: the image data to consider.
    /// - Returns: A string representing the type of the image format container such as public.heic, public.jpeg, etc.
    @objc class func imageFormat(fromImageData imageData: NSData) -> String? {
        guard let source: CGImageSource = CGImageSourceCreateWithData(imageData, nil) else { return nil }
        guard let type = CGImageSourceGetType(source) as? String else { return nil }
        return type
    }
    
    /// Convert image data containing orientation transforms to the upright position. Additionally output as either GIF or PNG.
    /// - Parameter imageData: The input image data to alter.
    /// - Returns: Image data represented as a GIF if the input was GIF or PNG otherwise.
    @objc class func uprightPngOrGifData(fromImageData imageData: NSData) -> NSData {
        if let imageType = imageFormat(fromImageData: imageData),
           !imageType.lowercased().hasSuffix("gif"),
           let image = UIImage(data: imageData as Data) {

            let uprightImage = UIImage.imageRedrawnUpright(image: image)
            if let uprightImageData = uprightImage.pngData() {
                return NSData(data: uprightImageData)
            }
        }
        
        return imageData
    }
    
    @objc class func imageOrientation(fromImageData imageData: NSData) -> CGImagePropertyOrientation {
        guard let source: CGImageSource = CGImageSourceCreateWithData(imageData, nil) else { return .up }
        guard let properties: [CFString: Any] = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return .up }
        let orientationValue: CGImagePropertyOrientation = properties[kCGImagePropertyOrientation] as? CGImagePropertyOrientation ?? .up
        return orientationValue
    }
    
    @objc class func export(imageData: NSData, pathExtension: String, completion: @escaping ((URL) -> Void)) {
        let tmpDirURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let outputImagePath = tmpDirURL.appendingPathComponent(UUID().uuidString).appendingPathExtension(pathExtension)
        try? FileManager.default.removeItem(atPath: outputImagePath.path)
        imageData.write(to: outputImagePath, atomically: true)
        completion(outputImagePath)
    }
}
