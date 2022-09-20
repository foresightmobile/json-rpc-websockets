//
//  NativeWebSocket.swift
//  
//
//  Created by user on 20.09.2022.
//

import Foundation

@available(iOS 13.0, *)
class NativeWebSocket: NSObject, WebSocketProvider {

    weak var delegate: WebSocketProviderDelegate?
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    
    func connect(url: URL, queue: OperationQueue?) {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: queue)
        let socket = session.webSocketTask(with: url)
        socket.resume()
        self.session = session
        self.socket = socket
        self.receive()
        self.ping()
    }

    func send(message: URLSessionWebSocketTask.Message, completionHandler: @escaping (Error?) -> Void) {
        self.socket?.send(message, completionHandler: completionHandler)
    }
    
    private func receive() {
        self.socket?.receive { [weak self] message in
            guard let self = self else { return }
            
            switch message {
            case .success(.string(let string)):
                guard let data = string.data(using: .utf8) else {
                    return
                }
                self.delegate?.webSocket(self, didReceiveData: data)
                self.receive()

            case .success(_):
                debugPrint("Warning: Expected to receive string format but received a data. Check the websocket server config.")
                self.receive()
                            
            case .failure(_):
                self.disconnect()
            }
        }
    }
    
    func disconnect() {
        self.socket?.cancel(with: .goingAway, reason: nil)
        self.socket = nil
        self.session?.finishTasksAndInvalidate()
        self.delegate?.webSocketDidDisconnect(self)
    }
    
    private func ping() {
        socket?.sendPing { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                print(error.localizedDescription)
            } else {
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5) {
                    self.ping()
                }
            }
        }
    }
}

@available(iOS 13.0, *)
extension NativeWebSocket: URLSessionWebSocketDelegate, URLSessionDelegate  {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.delegate?.webSocketDidConnect(self)
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.disconnect()
    }
}

