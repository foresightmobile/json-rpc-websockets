# JSON-RPC WebSockets

JSON-RPC WebSockets is an open-source implementation of [JSON-RPC 2.0](https://www.jsonrpc.org/specification) using WebSockets.

Inspired by [rpc-websockets](https://www.npmjs.com/package/rpc-websockets).

```swift
let client = Client()

struct FeedUpdatedParameters: Codable {

}

// Subscribe to receiving notifications from the server.
try client.subscribe(to: "feedUpdated", type: FeedUpdatedParameters.self)

// Execute a closure when a subscribed notification has been received.
client.on(method: "feedUpdated", type: FeedUpdatedParameters.self) { parameters in

}

let parameters = FeedUpdatedParameters()

// Send a notification to the server.
client.notify(method: "openedNewsModule", parameters) { result in 

}

// Connect to the server.
client.connect(url: url) {

}

// Disconnect from the server.
client.disconnect {

}
```

## Compatibility

JSON-RPC WebSockets follows [SemVer 2.0.0](https://semver.org/#semantic-versioning-200).