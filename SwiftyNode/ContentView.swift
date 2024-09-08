//
//  ContentView.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 5/9/24.
//

import SwiftUI
import SwiftyNodeKit
import Log

struct ContentView: View {
    @AppStorage("moduleLocation")
    var moduleLocation: String = ""
    @AppStorage("githubOrg")
    var githubOrg: String = ""

    @State var nodeExt: NodeExtension?

    init() {
    }

    var body: some View {
        VStack {
            TextField("Module location:", text: $moduleLocation)
            if let nodeExt {
                InterfaceView(nodeExt: nodeExt)
            }
            Button("Run module") {
                Task {
                    await nodeExt?.terminate()
                    nodeExt = nil
                    guard let nodeRuntime = await NodeJS.builtin else {
                        Log.error("No node runtime found")
                        return
                    }
                    let moduleURL = URL(filePath: moduleLocation)
                    let interface = await NodeInterface(nodeRuntime: nodeRuntime, moduleLocation: moduleURL)
                    guard let communicator = try? await interface.runModule(targetFile: "index.js") else {
                        Log.error("Could not start module")
                        return
                    }
                    self.nodeExt = .init(communicator: communicator)
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
