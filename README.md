# SwiftyNode
An experiment for running a Node script via a Swift app

# Premise

Raycast is a native macOS app written in Swift. It has an extension ecosystem built using NodeJS. It must therefore have some way to 
not just run Node scripts from Swift, but also communicate between them.

This repository is my experimentation for building a working NodeJS-based extension system. 

# Running SwiftyNode

1. You must have Node installed
2. Run `npm install` in `octo-node` to install all dependencies
3. Run the SwiftyNode app from Xcode
4. Input the path to the `octo-node` folder (or any other compatible node project)
5. Press `Run module`
6. Play around with the buttons that appear. Some buttons may appear to do nothing - if so, check the console for relevant errors or 
information.
7. To terminate the app, press `Terminate`. This will dump the process's standard output to the `Module Output` area of the UI.

# How It Works

## Running Node

The `NodeInterface` factory object's `executeModule` and `runModule` functions use the `Process` object to spawn an external process. 
It also uses a `Pipe` object to read from standard output, however this should only be done AFTER the process has been terminated, since
reading from standard output will need to wait for the process to terminate before returning.

SwiftyNode uses the `runModule` function to spawn a background Node process. The function returns a `NodeCommunicator` object, which 
is used to manage both the process and any communication with it.

## Communicating

To establish communication between the two processes, I use Unix Domain Sockets. The procedure to connect is:
1. (Swift) Generates a path for the socket, in the format of `/tmp/module-[UUID-HERE].sock`
2. (Swift) Starts the socket
3. (Swift) Listen for connections, accept the first one
4. (Swift) Spawn the NodeJS process, with the socket path passed as a command-line parameter
5. (NodeJS) Connect to the socket

My implementation of Unix Domain Sockets is based on [this](https://gist.github.com/rouzbeh-abadi/7e6650f48b6643605c012a04068df533) and 
[this](https://gist.github.com/rouzbeh-abadi/3cdda4959e2360f0f9e4dabd819dd170).

### Writing

Sending to the socket is limited to 8192 bytes (on my machine).

The NodeJS side uses the `net` library, which handles breaking up the message into fragments. Writing is handled with a Mutex, to ensure
messages are sent one at a time.

For swift, I implemented splitting myself. Although the limit is above 8000 bytes, I chose to have each fragment be a maximum of 4096 
bytes long.

To allow the reader to identify where messages start and end, each message has `[START: {id}]` and `[END: {id}]` appended to the start 
and end, respectively. The ID is a random number between 0 and 10,000. The reason for a unique ID is so that the contents of the message are
unlikely to interfere with the reading of the message.

### Reading

Reading from the socket is limited to 8192 bytes (on my machine). Fragments read from the socket aren't guarenteed to match up completely 
with what is sent - a single fragment may contain multiple messages (if they are small and sent soon after each other), or part of a larger
message that cannot be sent/read as a single fragment.

Both NodeJS and Swift use a `ChunkAssembler` object to process reading. Whenever fragments are read, they are passed to the assembler
for processing. Each fragment is added to a buffer, and the assembler looks for fragments. If a full message is found (with matching start 
and end markers), it moves on to the rest of the buffer to identify any further messages. Full messages read by the Swift side are processed
by the `NodeCommunicator`, and the `SwiftCommunicator` on the Node side. 

## Sending Orders

SwiftyNode uses the JSON-RPC spec to send messages. That means that requests follow this format:
```json
{
    "id": "a uuid, if the method expects a return value. Can be excluded.",
    "method": "name of the method",
    "params": "parameters, as a dictionary with string keys. Can be excluded."
}
```

And responses must follow this format:
```json
{
    "id": "the uuid of the function that this is a response to",
    "result": "the result of the function, arbritrary JSON. Mutually exclusive with error",
    "error": { // error thrown by the function. Mutually exclusive with result.
        "code": 0, // integer value here, following JSON-RPC spec
        "message": "description of the error"
    }
}
```

The `id` of a JSON request uniquely identifies the request. This ID is used in JSON response, which facilitates a request-response 
interaction. Both sides use their languages' respective callback and async/await systems to provide a simple function-like API for calling 
and providing methods, managed on the Swift side by the `NodeCommunicator`, and the `SwiftCommunicator` on the Node side. 

## API

### Swift

Creating the communicator
```swift
// moduleURL is the URL to the module's directory
let interface = await NodeInterface(nodeRuntime: nodeRuntime, moduleLocation: moduleURL)
communicator = try await interface.runModule()
```

Registering a function:
```swift
communicator.register(methodName: "swiftEcho") { params in
    Log.info("Echoing from node: \(params ?? [:])")
    return "it was echoed by Swift :)"
}
```

Calling a function:
```swift
let result = try await communicator.request(
    method: "nodeEcho", 
    params: ["message": "good morning!"], 
    returns: String.self
)
```

### Node

Creating the communicator
```swift
const communicator = new SwiftCommunicator(process.argv[2]);
```

Registering a function:
```js
communicator.register('nodeEcho', (params) => {
  console.log("Echoing from Swift:", params);
  return Promise.resolve("it was echoed by Node :D");
});
```

Calling a function:
```swift
communicator.request('swiftEcho', { message: "good evening!" })
  .then((response) => {
    // do something with response
  });
```

# Security

This implementation has several possible vulnurability points:
1. The socket currently accepts the very first connection made. A malicous actor may be able to hijack this connection, to pose as the node process.
    a. In the future, it would probably be wise to verify the connection first.
2. A request/response containing `[END: {id}]` containing the ID associated with the message's start prefix may cause a corrupted message.
    a. However, the process will probably recover when the next message is sent.
3. The code within the NodeJS process may be changed, possibly to inject malicious code. 
    a. We can probably use some sort of hashing system to ensure that the process's code is legitimate, first.

However, it is secure in the following aspects:
1. The NodeJS process can crash without the host app crashing
2. A hijacked socket will only be able to use the APIs exposed to the extension. It cannot execute arbritrary code

# Other Considerations

## Speed

A quick test of a `Swift --(requests)--> Node --(responds)--> Swift` round-trip function call takes about 1.5ms, or about 0.0015s. Although this is
acceptable for most UI-related cases (such as a button being pressed and showing an immediate result), large amounts of data or many requests may 
cause noticable delays. This duration may have multiple causes:
- The regex-based reading system, which may slow large messages
- The concurrency systems of Node and Swift
