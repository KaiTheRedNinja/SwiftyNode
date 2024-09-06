//
//  NodeCommunicator.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

class NodeCommunicator {
    var process: NodeProcess
//    var socket: Socket

    init(process: NodeProcess) {
        self.process = process
        fatalError("Not implemented")
    }

    func sendMessage() async throws {
        fatalError("Not implemented")
    }

    func readMessage() async throws {
        fatalError("Not implemented")
    }

    func terminate() {
        fatalError("Not implemented")
    }
}
