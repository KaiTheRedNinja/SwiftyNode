//
//  NodeInterface.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import Socket

/// An interface to run scripts with NodeJS
@NodeActor
public class NodeInterface {
    /// The NodeJS runtime
    let nodeRuntime: NodeJS
    /// The location of the module that this `NodeInterface` is running. This should be a directory.
    let moduleLocation: URL

    /// Creates a `NodeInterface` from a node runtime and the location of the module to run
    public init(nodeRuntime: NodeJS, moduleLocation: URL) {
        self.nodeRuntime = nodeRuntime
        self.moduleLocation = moduleLocation
    }

    /// Executes the module using `node [path here]`, and returns its output value.
    ///
    /// This function is a suspending function that waits until node has exited, then returns a string. If the file never
    /// exits, this function will not exit and will cause the caller to hang.
    ///
    /// By default, it executes `index.js` file within the ``moduleLocation``, but it can be changed.
    public func executeModule(targetFile: String = "index.js") throws -> String {
        try nodeRuntime.execute(moduleLocation.appendingPathComponent(targetFile))
    }

    /// Runs the module using `node [path here]`, without waiting for it to finish.
    ///
    /// This function is not a suspending function.
    ///
    /// By default, it executes `index.js` file within the ``moduleLocation``, but it can be changed.
    public func runModule(targetFile: String = "index.js") async throws -> String {
        let name = "/tmp/module_\(UUID().uuidString).sock"
        print(name)

        // start the process
        guard let process = try? nodeRuntime.run(moduleLocation.appendingPathComponent(targetFile), args: [name]) else {
            return ""
        }

        // wait for the server to start
        await withCheckedContinuation { cont in
            process.pipe.fileHandleForReading.readabilityHandler = { pipe in
                guard let line = String(data: pipe.availableData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                    print("Error decoding data: \(pipe.availableData)")
                    return
                }

                guard line == "Node.js server listening on \(name)" else {
                    print("Other console log: [\(line)]")
                    return
                }

                cont.resume()
            }
        }
        process.pipe.fileHandleForReading.readabilityHandler = nil

        // connect the socket
        let socket = try Socket.create(family: .unix, type: .stream, proto: .unix)
        try socket.connect(to: name)

        // close socket when the function returns
        defer {
            socket.close()
            print("Closed socket")
        }

        // send the message and wait for response
        try socket.write(from: "Good morning!".data(using: .utf8)!)
        let responseStr = try socket.readString() ?? "no response"

        print("Node responded with \(responseStr)")

        // terminate the process
        process.process.terminate()

        // read output
        do {
            guard let data = try process.pipe.fileHandleForReading.readToEnd() else { return "" }
            let output = String(data: data, encoding: .utf8)!
            return output
        } catch {
            return "Reading Error: \(error)"
        }
    }
}
