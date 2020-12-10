//
//  JSONRPCClient.swift
//  
//
//  Created by Michael Hamer on 12/4/20.
//

import Foundation

public class JSONRPCClient: NSObject {
    private var urlSession: URLSession?
    private var webSocketTask: URLSessionWebSocketTask?

    private var open: (() -> Void)?
    private var receivables = Dictionary<String, JSONRPCReceivable>()
    
    public func connect(url: URL, completion: @escaping () -> Void) {
        open = completion
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        receive()
    }
    
    public func call<T: Encodable, U: Decodable>(method: String, params: T, response: U.Type, timeout: TimeInterval = 5, completion: @escaping (U?) -> Void) {
        let request = JSONRPCRequest(method: method, params: params)
        
        guard let data = try? JSONEncoder().encode(request), let string = String(data: data, encoding: .utf8) else {
            fatalError("Could not encode request.")
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { timer in
            // Remove the receivable if the request hasn't received a response within the timeout.
            self.receivables.removeValue(forKey: request.id)
        }
        
        let receivable = JSONRPCReceivable(timer: timer, completion: { data in
            if let response = try? JSONDecoder().decode(JSONRPCResponse<U>.self, from: data) {
                if request.id == response.id {
                    
                    // Invalidate the current timeout timer which is running.
                    self.receivables[request.id]?.timer.invalidate()
                    
                    // Remove the receivable once the request has been paired with a matching response.
                    self.receivables.removeValue(forKey: request.id)
                    
                    completion(response.result)
                }
            }
        })
        
        receivables[request.id] = receivable
        
        let message = URLSessionWebSocketTask.Message.string(string)
        webSocketTask?.send(message) { error in
            if let error = error {
                print(error.localizedDescription)
            }
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
                            self.receivables.forEach {
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

extension JSONRPCClient: URLSessionWebSocketDelegate {
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        open?()
    }
}
