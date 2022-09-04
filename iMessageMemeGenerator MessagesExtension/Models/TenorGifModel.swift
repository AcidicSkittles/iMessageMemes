//
//  TenorGifModel.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation

struct TenorGifModel: Codable {
    let tags: [String]?
    let url: String?
    let media: [[String: TenorMediaModel]]?
    let created: Double?
    let shares: Int?
    let itemurl: String?
    let hasaudio: Bool?
    let title, id: String?
    let hascaption: Bool?
    
    var gifURL: String? {
        return media?.first?["gif"]?.url
    }
    
    var thumbnailURL: String? {
        return media?.first?["tinygif"]?.url
    }
    
    var gifSize: CGSize? {
        if let dims = media?.first?["gif"]?.dims, dims.count == 2 {
            return CGSize(width: dims[0], height: dims[1])
        } else {
            return nil
        }
    }
}
