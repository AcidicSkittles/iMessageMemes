//
//  TenorSearchResultsRepository.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation

class TenorSearchResultsRepository: NSObject {
    private var nextPagePositionId: String?
    private(set) var searchResults: [TenorGifModel] = []
    private(set) var isLoading: Bool = false
    private var searchText: String?
    
    func search(_ searchText: String?, completion: @escaping ((Error?) -> Void)) {
        self.searchText = searchText
        self.nextPagePositionId = nil
        
        self.retrieveImages(searchText: searchText, completion: completion)
    }
    
    func loadNextPage(completion: @escaping ((Error?) -> Void)) {
        guard let nextPagePositionId = self.nextPagePositionId else { return }
        
        self.retrieveImages(searchText: self.searchText, nextPagePositionId: nextPagePositionId, completion: completion)
    }
    
    private func retrieveImages(searchText: String?, nextPagePositionId: String? = nil, completion: @escaping ((Error?) -> Void)) {
        self.isLoading = true
        
        TenorAPI.search(searchText, nextPagePositionId: nextPagePositionId) { (tenorSearchResults, error) in
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
}
