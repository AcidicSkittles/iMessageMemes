//
//  Loading.swift
//  iMessageExtension
//
//  Created by Derek Buchanan on 2/23/22.
//  Copyright © 2022 Derek Buchanan. All rights reserved.
//

import UIKit
import FLAnimatedImage

public protocol LoadableView: AnyObject {
    var loadingView: LoadingView { get set }
}


/// iMessage extensions do not have a "keyWindow" like traditional apps, so we will create a barebones loading view
public class LoadingView: UIView {

    @IBOutlet weak var imageView: FLAnimatedImageView! {
        didSet {
            let path = Bundle.main.url(forResource: "poptart_cat", withExtension: "gif")!
            let data = try! Data(contentsOf: path)
            self.imageView.animatedImage = FLAnimatedImage.init(gifData: data)
            self.imageContainer.clipsToBounds = true
            self.imageContainer.layer.cornerRadius = 20
        }
    }
    
    @IBOutlet weak var imageContainer: UIView!
    
    public override var isHidden: Bool {
        didSet {
            self.superview?.bringSubviewToFront(self)
        }
    }
}

extension LoadableView where Self: UIViewController {
    func setupLoadingView() {
        self.loadingView.frame = self.view.bounds
        self.loadingView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.loadingView.isHidden = true
        self.view.addSubview(self.loadingView)
    }
}
