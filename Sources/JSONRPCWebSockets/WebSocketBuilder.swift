//
//  WebSocketBuilder.swift
//  
//
//  Created by user on 20.09.2022.
//

import Foundation

class WebSocketBuilder {
    public static func getWebSocketClient() -> WebSocketProvider {
        //TODO: Here we can provide
        ///- alternative implementations(Starscream for example)
        ///- test doubles for unit tests
        return NativeWebSocket()
    }
}
