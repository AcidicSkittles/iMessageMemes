//
//  MemeLabelMaker.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

import Foundation
import UIKit

@objc class MemeLabelMaker: NSObject {
    static let defaultMemeFont: String = "HelveticaNeue-Light"
    private static let minFontSize: CGFloat = 12.0
    private static let widthFunctionScaledFontSize: CGFloat = 15.0
    
    private override init() {}
    
    /// Generate a styled label to attach to your meme media.
    /// - Parameters:
    ///   - text: The text of the meme caption.
    ///   - insetXSpacing: The inset spacing on the left and right of the label.
    ///   - width: Total desired width of the label. The high is calculated automatically based on the amount of text you pass in. The font size used is a function of the width.
    /// - Returns: A styled UILabel with the correct minimized frame.
    @objc class func captionedLabel(withText text: String, insetXSpacing: Int, mediaWidth width: Int) -> UILabel {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: CGFloat(width - insetXSpacing * 2), height: CGFloat.greatestFiniteMagnitude))
        label.text = text
        label.textAlignment = .left
        label.textColor = UIColor(red: 25.0 / 255.0, green: 25.0 / 255.0, blue: 25.0 / 255.0, alpha: 1)
        label.numberOfLines = 0
        label.font = UIFont(name: defaultMemeFont, size: max(minFontSize, CGFloat(width) / widthFunctionScaledFontSize))
        label.sizeToFit()
        
        return label
    }
}
