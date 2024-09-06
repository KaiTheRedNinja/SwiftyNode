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
        let communicator = NodeCommunicator()
        let name = communicator.start()

        print("Starting process")

        // start the process
        guard let process = try? nodeRuntime.run(moduleLocation.appendingPathComponent(targetFile), args: [name]) else {
            return ""
        }
        
        communicator.process = process

        print("Started process")

        try await communicator.request(method: "hi", params: ["something": UUID()], returns: String.self)

        // terminate the process
        print("Terminating")
        communicator.terminate()

        // read output
        return communicator.readConsole()
    }
}
