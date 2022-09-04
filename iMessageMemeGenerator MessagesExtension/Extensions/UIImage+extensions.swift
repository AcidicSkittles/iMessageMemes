//
//  UIImage+extensions.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 8/31/22.
//

import Foundation
import UIKit

@objc extension UIImage {
    
    /// Grabs a screenshot of a view in the form of an image
    /// - Parameter view: the view to be screenshotted
    /// - Returns: image representation of the view
    class func image(view: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, 0.0)
        view.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return img
    }
    
    /// Resize an image and do not respect aspect ratio
    /// - Parameter newSize: desired new size
    /// - Returns: resized image to newSize
    func resizedImage(newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContext(newSize)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage
    }
    
    /// Redraw images that are not already in the true upright position. Images taken with camera may appear upright,
    /// but if camera was landscape, an additional underlying transform may have been applied to the image
    /// - Parameter image: The image to be rotated
    /// - Returns: A redrawn upright image with no transformations
    class func imageRedrawnUpright(image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        
        var transform: CGAffineTransform = .identity
        
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: image.size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: image.size.height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: image.size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: image.size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        let ctx: CGContext = CGContext(data: nil,
                                       width: Int(image.size.width),
                                       height: Int(image.size.height),
                                       bitsPerComponent: image.cgImage!.bitsPerComponent,
                                       bytesPerRow: 0,
                                       space: image.cgImage!.colorSpace!,
                                       bitmapInfo: image.cgImage!.bitmapInfo.rawValue)!
        ctx.concatenate(transform)
        
        switch image.imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            ctx.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.height, height: image.size.width))
        default:
            ctx.draw(image.cgImage!, in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        }
        
        let cgImg: CGImage = ctx.makeImage()!
        
        let result: UIImage = UIImage(cgImage: cgImg)
        
        return result
    }
}
