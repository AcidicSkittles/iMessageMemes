//
//  LayoutSettings.swift
//  iMessageMemeGenerator
//
//  Created by Derek Buchanan on 9/12/22.
//

import Foundation
import UIKit

struct LayoutSettings {
    static let spacing: CGFloat = 2
    
    static var itemsPerRow: Int {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return 6
        } else {
            return 3
        }
    }
}
