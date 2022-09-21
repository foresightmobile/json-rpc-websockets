//
//  Client.swift
//  
//
//  Created by user on 20.09.2022.
//

import Foundation

//MARK: - Client Interface
public class Client {
    public static func getClient() -> ClientProvider {
        let webSocket = WebSocketBuilder.getWebSocketClient()
        return ClientImpl(webSocketProvider: webSocket)
    }
}
