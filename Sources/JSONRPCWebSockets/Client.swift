//
//  Client.swift
//  
//
//  Created by Michael Hamer on 12/4/20.
//

import Foundation

public protocol ClientProvider: AnyObject {
    func connect(url: URL, queue: OperationQueue?, completion: @escaping () -> Void)
    func disconnect(completion: @escaping () -> Void)
    func notify<T: Codable>(method: String, parameters: T, completion: @escaping (Result<(), Error>) -> Void)
    func call<T: Codable, U: Decodable>(method: String, parameters: T, type: U.Type, timeout: TimeInterval?, completion: @escaping (Result<U?, Error>) -> Void)
    func subscribe<T: Codable>(to method: String, type: T.Type) throws
    func on<T: Codable>(method: String, type: T.Type, completion: @escaping (T) -> Void)
    func unsubscribe(from method: String)
}

class ClientImpl: ClientProvider {

    private let socket: WebSocketProvider

    private var receivableSubscribers = [ReceivableSubscriber]()
    private var notificationSubscribers = [NotificationSubscriber]()
    private let defaultInterval: TimeInterval = 5
        
    private var connectCompletion: (() -> Void)?
    private var disconnectCompletion: (() -> Void)?
    
    init(webSocketProvider: WebSocketProvider) {
        self.socket = webSocketProvider
        self.socket.delegate = self
    }

    func connect(url: URL, queue: OperationQueue?, completion: @escaping () -> Void) {
        socket.connect(url: url, queue: queue)
        connectCompletion = completion
    }
    
    func disconnect(completion: @escaping () -> Void) {
        socket.disconnect()
        disconnectCompletion = completion
    }
    
    func notify<T: Codable>(method: String, parameters: T, completion: @escaping (Result<(), Error>) -> Void) {
        let request = Request(id: nil, method: method, parameters: parameters)
        
        do {
            let data = try JSONEncoder().encode(request)
            
            guard let string = String(data: data, encoding: .utf8) else {
                throw ClientError.invalid(data: data, encoding: .utf8)
            }
            
            let message = URLSessionWebSocketTask.Message.string(string)
            socket.send(message: message) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func call<T: Codable, U: Decodable>(method: String, parameters: T, type: U.Type, timeout: TimeInterval?, completion: @escaping (Result<U?, Error>) -> Void) {
        let request = Request(method: method, parameters: parameters)
        
        guard let id = request.id else {
            return
        }
        
        do {
            let data = try JSONEncoder().encode(request)
            
            guard let string = String(data: data, encoding: .utf8) else {
                completion(.failure(ClientError.invalid(data: data, encoding: .utf8)))
                return
            }
            
            let timer = Timer.scheduledTimer(withTimeInterval: timeout ?? defaultInterval, repeats: false) { [weak self] timer in
                guard let self = self else { return }

                // Remove the receivable if the request hasn't received a response within the timeout.
                if let index = self.receivableSubscribers.firstIndex(where: { $0.id == id }) {
                    self.receivableSubscribers.remove(at: index)
                }
            }
            
            let completion = { [weak self] (data: Data) in
                guard let self = self else { return }
                // Attempt to decode the data to a matching type.
                guard let response = try? JSONDecoder().decode(Response<U>.self, from: data) else {
                    return
                }
                
                // Continue only if the request and response ids match.
                guard id == response.id else {
                    return
                }
                
                if let index = self.receivableSubscribers.firstIndex(where: { $0.id == id }) {
                    // Invalidate the current timeout timer which is running.
                    self.receivableSubscribers[index].timer.invalidate()
                    
                    // Remove the receivable once the request has been paired with a matching response.
                    self.receivableSubscribers.remove(at: index)
                    
                    completion(.success(response.result))
                }
            }
            
            receivableSubscribers.append(ReceivableSubscriber(id: id, timer: timer, completion: completion))
            
            let message = URLSessionWebSocketTask.Message.string(string)
            socket.send(message: message) { err in
                if let error = err {
                    print(error.localizedDescription)
                }
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    func subscribe<T: Codable>(to method: String, type: T.Type) throws {
        // Only allow subscribing to a method once.
        guard notificationSubscribers.first(where: { $0.method == method }) == nil else {
            throw ClientError.duplicateSubscription
        }
        
        notificationSubscribers.append(NotificationSubscriber(method: method, completion: nil))
    }
    
    func on<T: Codable>(method: String, type: T.Type, completion: @escaping (T) -> Void) {
        if let index = notificationSubscribers.firstIndex(where: { $0.method == method }) {
            notificationSubscribers[index].completion = { [weak self] data in
                guard let self = self else { return }
                // Attempt to decode the data to a matching type.
                let notification = try JSONDecoder().decode(Request<T>.self, from: data)
                
                // There's a chance that two methods point to one type.
                guard self.notificationSubscribers[index].method == notification.method else {
                    return
                }
                
                completion(notification.parameters)
            }
        }
    }
    
    func unsubscribe(from method: String) {
        if let index = notificationSubscribers.firstIndex(where: { $0.method == method }) {
            notificationSubscribers.remove(at: index)
        }
    }
    
    private func updateSubscribers(with data: Data) {
        self.receivableSubscribers.forEach {
            $0.completion(data)
        }
        
        self.notificationSubscribers.forEach {
            do {
                try $0.completion?(data)
            } catch {
                print(error.localizedDescription)
            }
        }
    }
}

//MARK: - WebSocketProviderDelegate
extension ClientImpl: WebSocketProviderDelegate {
    func webSocketDidConnect(_ webSocket: WebSocketProvider) {
        connectCompletion?()
    }
    
    func webSocketDidDisconnect(_ webSocket: WebSocketProvider) {

        disconnectCompletion?()
    }
    
    func webSocket(_ webSocket: WebSocketProvider, didReceiveData data: Data) {
        self.updateSubscribers(with: data)
    }
}
