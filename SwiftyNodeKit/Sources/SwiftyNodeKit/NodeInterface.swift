//
//  NodeInterface.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation
import IPCSocket

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
    public func runModule(targetFile: String = "index.js") async throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("module_\(UUID().uuidString).sock")
        print(temp)
        guard let socketAddr = makeSocket(path: temp.standardizedFileURL.path) else {
            print("Did not create socket")
            return
        }
        beginListening(socket: socketAddr)
        Task { @MainActor in
            acceptConnection(socket: socketAddr)
        }

        let socket = try UniSocket(peer: temp.standardizedFileURL.path)
        try socket.attach()

        guard let process = try? nodeRuntime.run(moduleLocation.appendingPathComponent(targetFile), args: [temp.path]) else {
            return
        }
        process.process.waitUntilExit()

        try socket.close()

        return
    }
}
