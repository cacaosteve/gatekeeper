import Vapor

/// Middleware used to rate-limit a single route or a group of routes.
public struct GatekeeperMiddleware: Middleware {
    private let config: GatekeeperConfig?
    private let keyMaker: GatekeeperKeyMaker?
    private let error: Error?
    
    /// Initialize a new middleware for rate-limiting routes, by optionally overriding default configurations.
    ///
    /// - Parameters:
    ///     - config: Override `GatekeeperConfig` instead of using the default `app.gatekeeper.config`
    ///     - keyMaker: Override `GatekeeperKeyMaker` instead of using the default `app.gatekeeper.keyMaker`
    ///     - config: Override the `Error` thrown when the user is rate-limited instead of using the default error.
    public init(config: GatekeeperConfig? = nil, keyMaker: GatekeeperKeyMaker? = nil, error: Error? = nil) {
        self.config = config
        self.keyMaker = keyMaker
        self.error = error
    }
    
    public func respond(to request: Request, chainingTo next: Responder) -> EventLoopFuture<Response> {
        let gatekeeper = request.gatekeeper(config: config, keyMaker: keyMaker)
        
        return gatekeeper.gatekeep(on: request, throwing: self.error ?? Abort(.tooManyRequests))
            .flatMap { next.respond(to: request) }
            .flatMapError { error in
                // Check if the error is a too many requests error
                if let abortError = error as? Abort, abortError.status == .tooManyRequests {
                    // Create a custom response with plain text
                    let response = Response(status: .tooManyRequests, body: .init(string: "slow down"))
                    response.headers.add(name: .contentType, value: "text/plain")
                    return request.eventLoop.makeSucceededFuture(response)
                } else {
                    // Forward other errors to the default error handler
                    return request.eventLoop.makeFailedFuture(error)
                }
            }
    }

}
