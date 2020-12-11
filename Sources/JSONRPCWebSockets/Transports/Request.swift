//
//  Request.swift
//  
//
//  Created by Michael Hamer on 12/8/20.
//

import Foundation

struct Request<T: Codable>: Codable {
    var jsonrpc: String
    var id: String?
    var method: String
    var params: T
    
    init(method: String, params: T) {
        self.jsonrpc = "2.0"
        self.id = UUID().uuidString
        self.method = method
        self.params = params
    }
}
