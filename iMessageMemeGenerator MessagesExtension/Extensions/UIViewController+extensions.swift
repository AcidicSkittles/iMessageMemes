//
//  UIViewController+extensions.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation
import UIKit

extension UIViewController {
    func show(alert: String) {
        let alert = UIAlertController(title: "", message: alert, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}
