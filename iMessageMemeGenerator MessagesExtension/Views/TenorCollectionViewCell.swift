//
//  TenorCollectionViewCell.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import UIKit
import FLAnimatedImage
import Nuke
import NukeFLAnimatedImagePlugin

class TenorCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var imageView: FLAnimatedImageView!
    
    func setup(_ model: TenorGifModel) {
        if let urlStr = model.thumbnailURL, let url = URL(string: urlStr) {
            Nuke.loadImage(with: url, into: imageView)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        Nuke.cancelRequest(for: imageView)
        imageView.animatedImage = nil
        imageView.image = nil
    }
}
