//
//  ChunkAssembler.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 7/9/24.
//

import Foundation

class ChunkAssembler {
    private var buffer: String = ""
    var chunkCallback: ((String) -> Void)?

    init(chunkCallback: ((String) -> Void)? = nil) {
        self.chunkCallback = chunkCallback
    }

    func processData(_ data: Data) {
        if let newString = String(data: data, encoding: .utf8) {
            buffer += newString
            extractChunks()
        } else {
            print("Error: Unable to decode data as UTF-8")
        }
    }

    private func extractChunks() {
        let pattern = "\\[START: (\\d+)\\]([\\s\\S]*?)\\[END: \\1\\]"
        let regex = try! NSRegularExpression(pattern: pattern, options: [])

        while true {
            guard let match = regex.firstMatch(in: buffer, options: [], range: NSRange(location: 0, length: buffer.utf16.count)) else {
                break
            }

            let idRange = Range(match.range(at: 1), in: buffer)!
            let contentRange = Range(match.range(at: 2), in: buffer)!

            let id = Int(buffer[idRange])!
            let content = String(buffer[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)

            processChunk(id: id, content: content)

            let fullMatchRange = Range(match.range, in: buffer)!
            buffer.removeSubrange(fullMatchRange.lowerBound..<buffer.endIndex)
        }
    }

    private func processChunk(id: Int, content: String) {
        // Call the external processChunk function here
        chunkCallback?(content)
    }
}
