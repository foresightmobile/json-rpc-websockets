//
//  JSONRPCReceivable.swift
//  
//
//  Created by Michael Hamer on 12/10/20.
//

import Foundation

class JSONRPCReceivable {
    let timer: Timer
    let completion: (Data) -> Void
    
    init(timer: Timer, completion: @escaping (Data) -> Void) {
        self.timer = timer
        self.completion = completion
    }
}
