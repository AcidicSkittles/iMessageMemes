//
//  TenorSearchResultsModel.swift
//  iMessageMemeGenerator MessagesExtension
//
//  Created by Derek Buchanan on 9/1/22.
//

import Foundation
import Alamofire

struct TenorSearchResultsModel: Codable {
    let weburl: String?
    let results: [TenorGifModel]?
    let next: String?
}

// MARK: - Alamofire response handlers

extension DataRequest {
    fileprivate func decodableResponseSerializer<T: Decodable>() -> DataResponseSerializer<T> {
        return DataResponseSerializer { _, _, data, error in
            guard error == nil else { return .failure(error!) }
            
            guard let data = data else {
                return .failure(AFError.responseSerializationFailed(reason: .inputDataNil))
            }
            
            return Result { try JSONDecoder().decode(T.self, from: data) }
        }
    }
    
    @discardableResult
    fileprivate func responseDecodable<T: Decodable>(queue: DispatchQueue? = nil, completionHandler: @escaping (DataResponse<T>) -> Void) -> Self {
        return response(queue: queue, responseSerializer: decodableResponseSerializer(), completionHandler: completionHandler)
    }
    
    @discardableResult
    func responseTenorModel(queue: DispatchQueue? = nil, completionHandler: @escaping (DataResponse<TenorSearchResultsModel>) -> Void) -> Self {
        return responseDecodable(queue: queue, completionHandler: completionHandler)
    }
}
