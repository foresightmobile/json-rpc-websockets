//
//  Client.swift
//  
//
//  Created by Michael Hamer on 12/4/20.
//

import Foundation

public class Client: NSObject {
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?

    private var open: (() -> Void)?
    
    private var receivableSubscribers = [ReceivableSubscriber]()
    private var notificationSubscribers = [NotificationSubscriber]()
    
    public func connect(url: URL, completion: @escaping () -> Void) {
        open = completion
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        receive()
    }
    
    public func call<T: Codable, U: Decodable>(method: String, parameters: T, type: U.Type, timeout: TimeInterval = 5, completion: @escaping (U?) -> Void) {
        let request = Request(method: method, parameters: parameters)
        
        guard let id = request.id else {
            return
        }
        
        guard let data = try? JSONEncoder().encode(request), let string = String(data: data, encoding: .utf8) else {
            fatalError("Could not encode request.")
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { timer in
            // Remove the receivable if the request hasn't received a response within the timeout.
            if let index = self.receivableSubscribers.firstIndex(where: { $0.id == id }) {
                self.receivableSubscribers.remove(at: index)
            }
        }
        
        let completion = { (data: Data) in
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
                    
                completion(response.result)
            }
        }
        
        receivableSubscribers.append(ReceivableSubscriber(id: id, timer: timer, completion: completion))
        
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print(error.localizedDescription)
            }
        }
    }
    
    public func subscribe<T: Codable>(to method: String, type: T.Type) throws {
        // Only allow subscribing to a method once.
        guard notificationSubscribers.first(where: { $0.method == method }) == nil else {
            throw ClientError.duplicateSubscription
        }
        
        notificationSubscribers.append(NotificationSubscriber(method: method, completion: nil))
    }
    
    public func on<T: Codable>(method: String, type: T.Type, completion: @escaping (T) -> Void) {
        if let index = notificationSubscribers.firstIndex(where: { $0.method == method }) {
            notificationSubscribers[index].completion = { data in
                // Attempt to decode the data to a matching type.
                guard let notification = try? JSONDecoder().decode(T.self, from: data) else {
                    return
                }
                
                // There's a chance that two methods point to one type.
                guard self.notificationSubscribers[index].method == method else {
                    return
                }
                
                DispatchQueue.main.async {
                    completion(notification)
                }
            }
        }
    }
    
    public func unsubscribe(from method: String) {
        if let index = notificationSubscribers.firstIndex(where: { $0.method == method }) {
            notificationSubscribers.remove(at: index)
        }
    }

    private func receive() {
        webSocketTask?.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    print("Received data: \(data.count)")
                case .string(let string):
                    guard let data = string.data(using: .utf8) else {
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.receivableSubscribers.forEach {
                            $0.completion(data)
                        }
                        
                        self.notificationSubscribers.forEach {
                            $0.completion?(data)
                        }
                    }
                default:
                    fatalError("Unknown success message received.")
                }
            case .failure(let error):
                print(error.localizedDescription)
            }
            
            self.receive()
        }
    }
}

extension Client: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        open?()
    }
}
