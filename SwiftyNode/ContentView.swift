//
//  ContentView.swift
//  SwiftyNode
//
//  Created by Kai Quan Tay on 5/9/24.
//

import SwiftUI

struct ContentView: View {
    let nodeLocation: String

    @AppStorage("moduleLocation") var moduleLocation: String = ""
    @State var moduleOutput: String = ""

    init() {
        let nodeString = shell("where node").trimmingCharacters(in: .whitespacesAndNewlines)
        guard nodeString.hasSuffix("node") else {
            fatalError("Node not found")
        }
        nodeLocation = nodeString
    }

    var body: some View {
        VStack {
            Text("Node location: " + nodeLocation)
            Text("Node version: " + shell("\(nodeLocation) --version"))
            TextField("Module location:", text: $moduleLocation)
            Button("Run module") {
                moduleOutput = shell("\(nodeLocation) \(moduleLocation)/index.js")
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

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)!

    return output
}

#Preview {
    ContentView()
}
