//
//  ReceivableSubscriber.swift
//  
//
//  Created by Michael Hamer on 12/10/20.
//

import Foundation

struct ReceivableSubscriber {
    let timer: Timer
    let completion: (Data) -> Void
}
