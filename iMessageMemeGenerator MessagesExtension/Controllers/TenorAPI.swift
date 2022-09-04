//
//  TenorAPI.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation
import Alamofire

enum TenorApiError: Error {
    case unknown
}

class TenorAPI: NSObject {
    static let shared = TenorAPI()

    fileprivate static let APIKey = "LIVDSRZULELA"
    fileprivate static let limit = 20
    fileprivate static let baseURL = "https://api.tenor.com/v1/"
    fileprivate static let defaultParams = "key=\(APIKey)&contentfilter=off&media_filter=minimal&limit=\(limit)"
    
    static let searchURL = "\(baseURL)search?\(defaultParams)"
    static let trendingURL = "\(baseURL)trending?\(defaultParams)"
    static let registerURL = "\(baseURL)registershare?key=\(APIKey)"
    
    static func search(_ searchText: String, next: String?, completion: @escaping ((TenorSearchResultsModel?, Error?) -> Void)) {
        let nextStr = (next != "0") ? "&pos=\(next!)" : ""
        let escapedString = searchText.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        var searchUrl = "\(TenorAPI.searchURL)&q=\(escapedString)"
        
        if escapedString.isEmpty {
            searchUrl = TenorAPI.trendingURL
        }
        
        if let url = URL(string: "\(searchUrl)\(nextStr)") {
            Alamofire.request(url).responseTenorModel { response in
                if let model = response.result.value {
                    completion(model, nil)
                } else if response.error != nil {
                    completion(nil, response.error)
                } else {
                    completion(nil, TenorApiError.unknown)
                }
            }
        } else {
            completion(nil, .none)
        }
    }
    
    static func registerShare(searchText: String?, gifId: String?) {
        guard let searchText = searchText, let gifId = gifId else { return }
        
        let escapedString = searchText.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? ""
        let registerShareUrl = "\(TenorAPI.registerURL)&id=\(gifId)&q=\(escapedString)"
        
        Alamofire.request(registerShareUrl).response { (response) in
            print(response)
            print(String(data: response.data ?? Data(), encoding: .utf8) ?? "")
        }
    }
}