//
//  WebSocketProvider.swift
//  
//
//  Created by user on 20.09.2022.
//

import Foundation

protocol WebSocketProvider: AnyObject {
    var delegate: WebSocketProviderDelegate? { get set }
    func connect(url: URL, queue: OperationQueue?)
    func disconnect()
    func send(message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void)
}

protocol WebSocketProviderDelegate: AnyObject {
    func webSocketDidConnect(_ webSocket: WebSocketProvider)
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider)
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data)
}
