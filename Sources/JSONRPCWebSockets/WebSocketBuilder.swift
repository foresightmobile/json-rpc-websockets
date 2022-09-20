//
//  WebSocketBuilder.swift
//  
//
//  Created by user on 20.09.2022.
//

import Foundation

class WebSocketBuilder {
    public static func getWebSocketClient() -> WebSocketProvider {
        return NativeWebSocket()
    }
}
