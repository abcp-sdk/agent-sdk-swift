// Agent typed client SDK for Swift (agent.v1.AgentService).
//
// Pure Connect client — no easylab gateway, no REST. The typed RPC client is
// generated from agent/v1/agent.proto by buf; this package adds a
// ProtocolClient (URLSession, Connect protocol over HTTP/2/TLS) with bearer
// auth and packs the agent.v1.AgentService surface.
//
// Usage:
//   let client = AgentClient(baseUrl: "https://agent.example.com", token: "")
//   let sessions = try await client.listSessions()
import Connect
import Foundation

/// Interceptor that adds an `Authorization: Bearer <token>` header to every
/// outbound request (both unary and streaming).
final class AgentBearerInterceptor: UnaryInterceptor, StreamInterceptor, Sendable {
    private let token: String

    init(token: String) {
        self.token = token
    }

    @Sendable
    func handleUnaryRequest<Message: ProtobufMessage>(
        _ request: HTTPRequest<Message>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Message>, ConnectError>) -> Void
    ) {
        var headers = request.headers
        headers["Authorization"] = ["Bearer \(self.token)"]
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )))
    }

    @Sendable
    func handleStreamStart(
        _ request: HTTPRequest<Void>,
        proceed: @escaping @Sendable (Result<HTTPRequest<Void>, ConnectError>) -> Void
    ) {
        var headers = request.headers
        headers["Authorization"] = ["Bearer \(self.token)"]
        proceed(.success(HTTPRequest(
            url: request.url,
            headers: headers,
            message: request.message,
            method: request.method,
            trailers: request.trailers,
            idempotencyLevel: request.idempotencyLevel
        )))
    }
}

/// The typed agent client over agent.v1.AgentService.
public final class AgentClient: Sendable {
    public let agent: Agent_V1_AgentServiceClientInterface
    private let client: ProtocolClient

    public init(
        baseUrl: String,
        token: String,
        httpClient: HTTPClientInterface = URLSessionHTTPClient()
    ) {
        let host = baseUrl.hasSuffix("/")
            ? String(baseUrl.dropLast())
            : baseUrl
        let protocolClient = ProtocolClient(
            httpClient: httpClient,
            config: ProtocolClientConfig(
                host: host,
                networkProtocol: .connect,
                codec: ProtoCodec(),
                interceptors: [
                    InterceptorFactory { _ in AgentBearerInterceptor(token: token) },
                ]
            )
        )
        self.client = protocolClient
        self.agent = Agent_V1_AgentServiceClient(client: protocolClient)
    }

    /// List sessions.
    public func listSessions() async throws -> [Agent_V1_Session] {
        let res = await self.agent.listSessions(request: Agent_V1_ListSessionsRequest(), headers: [:])
        if let err = res.error {
            throw err
        }
        guard let msg = res.message else {
            throw ConnectError(code: .unknown, message: "empty response", exception: nil, details: [], metadata: [:])
        }
        return msg.sessions
    }
}
