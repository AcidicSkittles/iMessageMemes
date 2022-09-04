//
//  TenorMediaModel.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation

struct TenorMediaModel: Codable {
    let url: String?
    let dims: [Int]?
    let preview: String?
    let size: Int?
    let duration: Double?
}
