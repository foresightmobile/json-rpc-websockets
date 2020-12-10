//
//  JSONRPCResponse.swift
//  
//
//  Created by Michael Hamer on 12/8/20.
//

import Foundation

struct JSONRPCResponse<T: Decodable>: Decodable {
    let jsonrpc: String
    let id: String
    let result: T?
}
