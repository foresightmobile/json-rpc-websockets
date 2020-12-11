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
    
    private var receivableSubscribers = Dictionary<String, ReceivableSubscriber>()
    private var notificationSubscribers = [NotificationSubscriber]()
    
    public func connect(url: URL, completion: @escaping () -> Void) {
        open = completion
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        receive()
    }
    
    public func call<T: Codable, U: Decodable>(method: String, params: T, response: U.Type, timeout: TimeInterval = 5, completion: @escaping (U?) -> Void) {
        let request = Request(method: method, params: params)
        
        guard let data = try? JSONEncoder().encode(request), let string = String(data: data, encoding: .utf8) else {
            fatalError("Could not encode request.")
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { timer in
            // Remove the receivable if the request hasn't received a response within the timeout.
            if let id = request.id {
                self.receivableSubscribers.removeValue(forKey: id)
            }
        }
        
        let receivable = ReceivableSubscriber(timer: timer, completion: { data in
            if let response = try? JSONDecoder().decode(Response<U>.self, from: data) {
                if let id = request.id, id == response.id {
                    
                    // Invalidate the current timeout timer which is running.
                    self.receivableSubscribers[id]?.timer.invalidate()
                    
                    // Remove the receivable once the request has been paired with a matching response.
                    self.receivableSubscribers.removeValue(forKey: id)
                    
                    completion(response.result)
                }
            }
        })
        
        if let id = request.id {
            receivableSubscribers[id] = receivable
        }
        
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
                    if let data = string.data(using: .utf8) {
                        // Only tinker with our receivables on the main thread.
                        DispatchQueue.main.async {
                            self.receivableSubscribers.forEach {
                                $0.value.completion(data)
                            }
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
