//
//  TenorSearchResultsController.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation

class TenorSearchResultsController: NSObject {
    var next: String?
    var searchResults = [TenorGifModel]()
    var isLoading = false
    var searchStr = ""
    
    func search(_ searchText: String, completion: @escaping ((Error?) -> Void)) {
        isLoading = true
        searchStr = searchText
        next = nil
        TenorAPI.search(searchText, next: "0") { (tenorSearchResults, error) in
            self.isLoading = false
            guard let tenorSearchResults = tenorSearchResults else {
                completion(error)
                return
            }
            
            self.next = tenorSearchResults.next
            self.searchResults = tenorSearchResults.results ?? []
            completion(nil)
        }
    }
    
    func loadPage(_ next: String?, completion: @escaping ((Error?) -> Void)) {
        isLoading = true
        
        TenorAPI.search(searchStr, next: next) { (tenorSearchResults, error) in
            self.isLoading = false
            guard let tenorSearchResults = tenorSearchResults else {
                completion(error)
                return
            }
            
            self.next = tenorSearchResults.next
            self.searchResults.append(contentsOf: tenorSearchResults.results ?? [])
            completion(nil)
        }
    }
    
    func loadNextPage(completion: @escaping ((Error?) -> Void)) {
        if let nextVal = next, nextVal != "0" {
            loadPage(nextVal, completion: completion)
        }
    }
    
    func shouldLoadNextPage(_ currentItemIndex: Int) -> Bool {

        if !isLoading && currentItemIndex > (searchResults.count-10) {
            return true
        } else {
            return false
        }
    }
}
