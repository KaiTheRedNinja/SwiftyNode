//
//  ContentView.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 5/9/24.
//

import SwiftUI
import SwiftyNodeKit

struct ContentView: View {
    @AppStorage("moduleLocation") var moduleLocation: String = ""
    @State var moduleOutput: String = ""

    init() {
    }

    var body: some View {
        VStack {
            TextField("Module location:", text: $moduleLocation)
            Button("Run module") {
                Task {
                    guard let nodeRuntime = await NodeJS.builtin else {
                        moduleOutput = "No node runtime found"
                        return
                    }
                    let moduleURL = URL(filePath: moduleLocation)
                    moduleOutput = "Running \(moduleURL.standardizedFileURL.relativePath)"
                    let interface = await NodeInterface(nodeRuntime: nodeRuntime, moduleLocation: moduleURL)
                    do {
                        try await interface.runModule()
                        moduleOutput = "DONE!"
                    } catch {
                        moduleOutput = "ERROR: \(error)"
                    }
                }
            }
            Text("Module output:")
            GroupBox {
                ScrollView {
                    Text(moduleOutput)
                }
            }
            .frame(maxHeight: 400)
        }
        .padding()
    }
}

func shell(_ command: String) -> String {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["--login", "-c", command]
    task.launchPath = "/bin/zsh"
    task.standardInput = nil
    task.launch()

    do {
        guard let data = try pipe.fileHandleForReading.readToEnd() else { return "" }
        let output = String(data: data, encoding: .utf8)!
        return output
    } catch {
        return "ERROR: \(error)"
    }
}

#Preview {
    ContentView()
}
