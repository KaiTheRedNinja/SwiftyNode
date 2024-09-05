//
//  File.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 5/9/24.
//

import Foundation

/// Actor for the NodeJS runtime.
@globalActor public actor NodeActor {
    /// Shared singleton.
    public static let shared = NodeActor()

    /// Singleton initializer.
    private init() {}

    /// Convenience method that schedules a function to run on this actor's dedicated thread.
    /// - Parameters:
    ///   - resultType: Return type of the scheduled function.
    ///   - run: Function to run.
    /// - Returns: Whatever the function returns.
    public static func run<T: Sendable>(
        resultType _: T.Type = T.self,
        body run: @NodeActor () throws -> T
    ) async rethrows -> T {
        return try await run()
    }
}
