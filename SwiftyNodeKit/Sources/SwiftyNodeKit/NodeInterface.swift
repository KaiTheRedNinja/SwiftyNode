//
//  NodeInterface.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

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

        // create socket
        let socket = Server(socketPath: name)
        socket.startBroadcasting()

        print("Starting process")

        // start the process
        guard let process = try? nodeRuntime.run(moduleLocation.appendingPathComponent(targetFile), args: [name]) else {
            return ""
        }

        print("Started process")

        try await Task.sleep(nanoseconds: 1_000_000_000)

        // send the message and wait for response
        socket.sendData("Good morning!".data(using: .utf8)!)
        socket.readData()

        try await Task.sleep(nanoseconds: 1_000_000_000)

        // terminate the process
        print("Terminating")
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
