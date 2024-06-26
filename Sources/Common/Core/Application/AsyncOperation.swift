//
//  Copyright © 2016 Cleverlance. All rights reserved.
//

public protocol Execution {
    func cancel()
}

public enum AsyncOperationError: Error {
    case executionFailed
}

public protocol AsyncOperationProtocol {
    associatedtype Input
    associatedtype Output

    @discardableResult
    func execute(with input: Input, completion: @escaping (OperationResult<Output>) -> Void) -> Execution?

    #if compiler(>=5.5)
    @available(iOS 13.0, *)
    @discardableResult
    func execute(with input: Input) async throws -> Output
    #endif
}

extension AsyncOperationProtocol where Input == Empty {
    @discardableResult
    public func execute(completion: @escaping (OperationResult<Output>) -> Void) -> Execution? {
        return execute(with: Empty(), completion: completion)
    }

    #if compiler(>=5.5)
    @available(iOS 13.0, *)
    @discardableResult
    public func execute() async throws -> Output {
        return try await execute(with: Empty())
    }
    #endif
}

public typealias AsyncOperation<Input, Output> = TaggedAsyncOperation<Input, Output, Void>

open class TaggedAsyncOperation<Input, Output, Tag>: AbstractClass, AsyncOperationProtocol {
    public init() {}

    @discardableResult
    open func execute(with input: Input, completion: @escaping (OperationResult<Output>) -> Void) -> Execution? {
        virtualMethod
    }

    #if compiler(>=5.5)
    @available(iOS 13.0, *)
    @discardableResult
    public func execute(with input: Input) async throws -> Output {
        return try await withCheckedThrowingContinuation { continuation in
            execute(with: input) { result in
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    @available(iOS 13.0, *)
    private func executeAsyncWithSemaphore(input: Input) async throws -> Output {
        try await withCheckedThrowingContinuation { continuation in
            let semaphore = DispatchSemaphore(value: 0)
            var result: OperationResult<Output>?

            execute(with: input) { operationResult in
                result = operationResult
                semaphore.signal()
            }

            semaphore.wait()

            if let result = result {
                switch result {
                case .success(let output):
                    continuation.resume(returning: output)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            } else {
                continuation.resume(throwing: AsyncOperationError.executionFailed)
            }
        }
    }
    #endif
}
