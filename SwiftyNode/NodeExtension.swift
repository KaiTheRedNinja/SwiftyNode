//
//  NodeExtension.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 7/9/24.
//

import Foundation
import SwiftyNodeKit
import Log
import NodeMacro

@NodeMethodGroup
protocol ButtonsAPI {
    func buttonPressed(id: String) async throws
}

@NativeMethodGroup
protocol UserInterfaceAPI: NativeMethodGroupProtocol {
    func drawButtons(buttons: [NodeButton]) async throws
    func writeToTextDisplay(text: String) async throws
}

struct NodeButton: Codable {
    var title: String
    var id: String
}

class NodeExtension: ObservableObject {
    private var communicator: NodeCommunicator

    public var buttonsAPI: ButtonsAPIMethodGroup
    @Published public var moduleOutput: String = ""
    @Published public var buttons: [NodeButton] = []

    init(communicator: NodeCommunicator) {
        self.communicator = communicator
        self.buttonsAPI = .init(communicator: communicator)
        self.registerWithCommunicator(communicator)
    }

    func terminate() async {
        await communicator.terminate()
        await moduleOutput = communicator.readConsole()
    }
}

extension NodeExtension: UserInterfaceAPI {
    func drawButtons(buttons: [NodeButton]) async throws {
        Log.info("Drawing buttons: \(buttons)")
        Task { @MainActor in
            self.buttons = buttons
        }
    }

    func writeToTextDisplay(text: String) async throws {
        Log.info("Writing text on display: \(buttons)")
        Task { @MainActor in
            self.moduleOutput = text
        }
    }
}
