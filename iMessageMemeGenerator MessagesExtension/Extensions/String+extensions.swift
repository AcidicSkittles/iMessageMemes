//
//  String+extensions.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/2/22.
//

import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "\(self)_comment")
    }
    
    func localized(_ args: CVarArg...) -> String {
        return String(format: localized, args)
    }
}
