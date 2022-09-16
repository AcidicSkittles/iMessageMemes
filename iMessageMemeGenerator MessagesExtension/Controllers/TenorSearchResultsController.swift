//
//  TenorSearchResultsController.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation

class TenorSearchResultsController: NSObject {
    private var nextPagePositionId: String?
    var searchResults: [TenorGifModel] = []
    var isLoading: Bool = false
    var searchText: String = ""
    
    func search(_ searchText: String, completion: @escaping ((Error?) -> Void)) {
        self.isLoading = true
        self.searchText = searchText
        self.nextPagePositionId = nil
        TenorAPI.search(searchText, nextPagePositionId: "0") { (tenorSearchResults, error) in
            self.isLoading = false
            guard let tenorSearchResults = tenorSearchResults else {
                completion(error)
                return
            }
            
            self.nextPagePositionId = tenorSearchResults.next
            self.searchResults = tenorSearchResults.results ?? []
            completion(nil)
        }
    }
    
    func loadPage(_ nextPagePositionId: String?, completion: @escaping ((Error?) -> Void)) {
        self.isLoading = true
        
        TenorAPI.search(self.searchText, nextPagePositionId: nextPagePositionId) { (tenorSearchResults, error) in
            self.isLoading = false
            guard let tenorSearchResults = tenorSearchResults else {
                completion(error)
                return
            }
            
            self.nextPagePositionId = tenorSearchResults.next
            self.searchResults.append(contentsOf: tenorSearchResults.results ?? [])
            completion(nil)
        }
    }
    
    func loadNextPage(completion: @escaping ((Error?) -> Void)) {
        if let nextPagePositionId = self.nextPagePositionId, nextPagePositionId != "0" {
            self.loadPage(nextPagePositionId, completion: completion)
        }
    }
    
    func shouldLoadNextPage(_ currentItemIndex: Int) -> Bool {
        let loadOffsetRows = 3
        if !self.isLoading && currentItemIndex > (self.searchResults.count - LayoutSettings.itemsPerRow * loadOffsetRows) {
            return true
        } else {
            return false
        }
    }
}
