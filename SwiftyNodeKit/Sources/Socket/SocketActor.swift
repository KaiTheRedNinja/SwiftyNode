//
//  SocketActor.swift
//  SwiftyNodeKit
//
//  Created by Kai Quan Tay on 6/9/24.
//

import Foundation

/// Actor for the socket connections and reading
@globalActor public actor SocketActor {
    /// Shared singleton.
    public static let shared = SocketActor()

    /// Singleton initializer.
    private init() {}

    /// Convenience method that schedules a function to run on this actor's dedicated thread.
    /// - Parameters:
    ///   - resultType: Return type of the scheduled function.
    ///   - run: Function to run.
    /// - Returns: Whatever the function returns.
    public static func run<T: Sendable>(
        resultType _: T.Type = T.self,
        body run: @SocketActor () throws -> T
    ) async rethrows -> T {
        return try await run()
    }
}
