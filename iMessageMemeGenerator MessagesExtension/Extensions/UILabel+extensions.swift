//
//  UILabel+extensions.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/15/22.
//

import Foundation
import UIKit

extension UILabel: XIBLocalizable {
    @IBInspectable var xibLocalizationKey: String? {
        get { return nil }
        set(key) {
            text = key?.localized
        }
    }
}
