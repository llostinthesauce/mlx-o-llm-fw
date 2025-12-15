import Foundation
import Network
import ModelStoreKit

public final class HTTPServer {
    public let port: UInt16
    public let runner: any ModelRunner
    public let store: FileModelStore
    private var listener: NWListener?
    private let loggerQueue = DispatchQueue(label: "mlxserve.logger")

    public init(port: UInt16, runner: any ModelRunner, store: FileModelStore) {
        self.port = port
        self.runner = runner
        self.store = store
    }

    public func start() throws {
        let params = NWParameters.tcp
        let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        print("mlxserve listening on http://127.0.0.1:\(port)")

        listener.newConnectionHandler = { [weak self] conn in
            conn.start(queue: .global())
            self?.receive(on: conn, buffer: Data(), requestID: UUID().uuidString)
        }

        listener.start(queue: .global())
        RunLoop.main.run()
    }

    private func log(_ event: [String: Any]) {
        loggerQueue.async {
            if let data = try? JSONSerialization.data(withJSONObject: event, options: []),
               let line = String(data: data, encoding: .utf8) {
                print(line)
            }
        }
    }

    private func receive(on connection: NWConnection, buffer: Data, requestID: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = buffer
            if let data { buffer.append(data) }
            if isComplete || error != nil {
                Task {
                    await self.handleRequest(data: buffer, connection: connection, requestID: requestID)
                    connection.cancel()
                }
            } else {
                self.receive(on: connection, buffer: buffer, requestID: requestID)
            }
        }
    }

    private func handleRequest(data: Data, connection: NWConnection, requestID: String) async {
        guard let requestString = String(data: data, encoding: .utf8) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }

        let parts = requestString.components(separatedBy: "\r\n\r\n")
        guard let headerPart = parts.first else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }

        let headerLines = headerPart.split(separator: "\r\n")
        guard let requestLine = headerLines.first else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }

        var headerMap: [String: String] = [:]
        for line in headerLines.dropFirst() {
            let comps = line.split(separator: ":", maxSplits: 1)
            if comps.count == 2 {
                headerMap[String(comps[0]).lowercased()] = String(comps[1]).trimmingCharacters(in: .whitespaces)
            }
        }

        let lineParts = requestLine.split(separator: " ")
        guard lineParts.count >= 2 else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"bad request\"}")
            return
        }

        let method = lineParts[0]
        let path = lineParts[1]
        let bodyString = parts.count > 1 ? parts[1] : ""
        let bodyData = Data(bodyString.utf8)
        let start = Date()
        log(["level": "info", "msg": "request_start", "path": path, "req_id": requestID])

        if method == "GET" && path == "/api/health" {
            sendResponse(connection: connection, status: 200, body: "{\"status\":\"ok\"}")
            log(["level": "info", "msg": "request_end", "path": path, "req_id": requestID, "status": 200, "duration_ms": Int(Date().timeIntervalSince(start) * 1000)])
            return
        }

        if method == "GET" && path == "/api/version" {
            sendResponse(connection: connection, status: 200, body: "{\"version\":\"0.0.1\"}")
            log(["level": "info", "msg": "request_end", "path": path, "req_id": requestID, "status": 200, "duration_ms": Int(Date().timeIntervalSince(start) * 1000)])
            return
        }

        if method == "GET" && path == "/v1/models" {
            await handleListModels(connection: connection, requestID: requestID, start: start, path: String(path))
            return
        }

        if method == "POST" && path == "/api/generate" {
            await handleGenerate(body: bodyData, connection: connection, requestID: requestID, headers: headerMap, start: start, path: String(path))
            return
        }

        if method == "POST" && path == "/api/pull" {
            await handlePull(body: bodyData, connection: connection, requestID: requestID, start: start, path: String(path))
            return
        }

        if method == "POST" && path == "/api/chat" {
            await handleChat(body: bodyData, connection: connection, requestID: requestID, headers: headerMap, start: start, path: String(path))
            return
        }

        if method == "POST" && path == "/v1/chat/completions" {
            await handleOpenAIChat(body: bodyData, connection: connection, requestID: requestID, headers: headerMap, start: start, path: String(path))
            return
        }

        sendResponse(connection: connection, status: 404, body: "{\"error\":\"not found\"}")
        log(["level": "info", "msg": "request_end", "path": path, "req_id": requestID, "status": 404, "duration_ms": Int(Date().timeIntervalSince(start) * 1000)])
    }

    private func handleGenerate(body: Data, connection: NWConnection, requestID: String, headers: [String: String], start: Date, path: String) async {
        let decoder = JSONDecoder()
        guard let req = try? decoder.decode(OllamaGenerateRequest.self, from: body) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid json\"}")
            return
        }

        guard let genReq = RequestNormalizer.normalize(ollama: req) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid model tag\"}")
            return
        }
        await generateAndStream(genReq: genReq, stream: req.stream ?? false, connection: connection, requestID: requestID, openAIResponse: false, openAIModel: nil, headers: headers, start: start, path: path)
    }

    private func handlePull(body: Data, connection: NWConnection, requestID: String, start: Date, path: String) async {
        let decoder = JSONDecoder()
        guard let req = try? decoder.decode(PullRequest.self, from: body) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid json\"}")
            return
        }

        guard let tag = ModelTag(string: req.tag) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid tag\"}")
            return
        }

        let store: FileModelStore
        do {
            if let root = req.root {
                store = try FileModelStore(root: URL(fileURLWithPath: root, isDirectory: true))
            } else {
                store = try FileModelStore()
            }
        } catch {
            sendResponse(connection: connection, status: 500, body: "{\"error\":\"store init failed\"}")
            return
        }

        let artifactURL = URL(fileURLWithPath: req.artifact)
        let tokenizerURL = req.tokenizer.map { URL(fileURLWithPath: $0) }
        let builder = ModelSpecBuilder(store: store)
        let spec = ModelSpec(
            name: tag.name,
            version: tag.version ?? "latest",
            base: ModelSpec.Base(hfRepo: nil, revision: nil, localPath: artifactURL.path),
            format: "mlx",
            quantization: tag.variant,
            tokenizer: tokenizerURL?.lastPathComponent,
            promptTemplate: nil,
            defaults: nil,
            license: nil,
            metadata: ["source": "pull-api"]
        )

        do {
            let manifest = try await builder.build(
                spec: spec,
                options: ModelSpecBuildOptions(
                    artifactPath: artifactURL,
                    tokenizerPath: tokenizerURL
                )
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(manifest)
            if let body = String(data: data, encoding: .utf8) {
                sendResponse(connection: connection, status: 200, body: body)
            } else {
                sendResponse(connection: connection, status: 500, body: "{\"error\":\"encode\"}")
            }
        } catch {
            let message = (error as? ModelSpecBuilderError).map { "\($0)" } ?? "\(error)"
            sendResponse(connection: connection, status: 500, body: "{\"error\":\"\(message)\"}")
        }
    }

    private func handleListModels(connection: NWConnection, requestID: String, start: Date, path: String) async {
        do {
            let manifests = try await store.list()
            let payload: [[String: Any]] = manifests.map { manifest in
                [
                    "id": manifest.tag.displayName,
                    "object": "model",
                    "owned_by": "local",
                    "created": Int(manifest.createdAt.timeIntervalSince1970),
                    "size": manifest.sizeBytes
                ]
            }
            let resp: [String: Any] = ["object": "list", "data": payload]
            let data = try JSONSerialization.data(withJSONObject: resp, options: [])
            if let body = String(data: data, encoding: .utf8) {
                sendResponse(connection: connection, status: 200, body: body)
            } else {
                sendResponse(connection: connection, status: 500, body: "{\"error\":\"encode\"}")
            }
        } catch {
            sendResponse(connection: connection, status: 500, body: "{\"error\":\"list failed\"}")
        }
        log(["level": "info", "msg": "request_end", "path": path, "req_id": requestID, "status": 200, "duration_ms": Int(Date().timeIntervalSince(start) * 1000)])
    }

    private func handleChat(body: Data, connection: NWConnection, requestID: String, headers: [String: String], start: Date, path: String) async {
        let decoder = JSONDecoder()
        guard let req = try? decoder.decode(OllamaGenerateRequest.self, from: body) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid json\"}")
            return
        }
        guard let genReq = RequestNormalizer.normalize(ollama: req) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid model tag\"}")
            return
        }
        await generateAndStream(genReq: genReq, stream: req.stream ?? false, connection: connection, requestID: requestID, openAIResponse: false, openAIModel: nil, headers: headers, start: start, path: path)
    }

    private func handleOpenAIChat(body: Data, connection: NWConnection, requestID: String, headers: [String: String], start: Date, path: String) async {
        let decoder = JSONDecoder()
        guard let req = try? decoder.decode(OpenAIChatRequest.self, from: body) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid json\"}")
            return
        }
        guard let genReq = RequestNormalizer.normalize(openAI: req) else {
            sendResponse(connection: connection, status: 400, body: "{\"error\":\"invalid model tag\"}")
            return
        }
        await generateAndStream(genReq: genReq, stream: req.stream ?? false, connection: connection, requestID: requestID, openAIResponse: true, openAIModel: req.model, headers: headers, start: start, path: path)
    }

    private func generateAndStream(genReq: GenerationRequest, stream: Bool, connection: NWConnection, requestID: String, openAIResponse: Bool, openAIModel: String? = nil, headers: [String: String], start: Date, path: String) async {
        // Require manifest and verify
        guard let manifest = try? await store.manifest(for: ModelTag(name: genReq.model.name, variant: genReq.model.variant, version: genReq.model.version)) else {
            sendResponse(connection: connection, status: 404, body: "{\"error\":\"manifest not found\"}")
            log(["level": "error", "msg": "manifest missing", "model": genReq.model.displayName, "req_id": requestID])
            return
        }
        do {
            _ = try await store.verify(manifest: manifest)
        } catch {
            log(["level": "error", "msg": "manifest verification failed", "model": genReq.model.displayName, "req_id": requestID])
            sendResponse(connection: connection, status: 500, body: "{\"error\":\"manifest verification failed\"}")
            return
        }

        do {
            let loaded = try await runner.load(model: genReq.model, options: ModelLoadOptions(keepAlive: genReq.keepAlive))

            if stream {
                let sse = (headers["accept"]?.contains("text/event-stream") ?? false)
                sendStreamingResponse(connection: connection, genReq: genReq, loaded: loaded, runner: runner, requestID: requestID, openAIResponse: openAIResponse, openAIModel: openAIModel, sse: sse)
                return
            }

            var tokens: [String] = []
            var finalText = ""
            var generatedCount = 0

            for try await event in runner.generate(request: genReq, using: loaded) {
                switch event {
                case let .token(tok):
                    tokens.append(tok)
                    generatedCount += 1
                case let .completed(res):
                    finalText = res.text
                }
            }

            if openAIResponse {
                let now = Int(Date().timeIntervalSince1970)
                let choice = OpenAIChatChoice(index: 0, message: OpenAIChatMessage(role: "assistant", content: finalText), finishReason: "stop")
                let usage = OpenAIUsage(promptTokens: tokens.count, completionTokens: generatedCount, totalTokens: tokens.count + generatedCount)
                let resp = OpenAIChatResponse(id: "chatcmpl-\(UUID().uuidString)", object: "chat.completion", created: now, model: openAIModel ?? genReq.model.displayName, choices: [choice], usage: usage)
                let data = try JSONEncoder().encode(resp)
                if let body = String(data: data, encoding: .utf8) {
                    sendResponse(connection: connection, status: 200, body: body)
                } else {
                    sendResponse(connection: connection, status: 500, body: "{\"error\":\"encode\"}")
                }
            } else {
                let resp = ["model": genReq.model.displayName, "response": finalText, "tokens": tokens] as [String: Any]
                let data = try JSONSerialization.data(withJSONObject: resp, options: [])
                if let body = String(data: data, encoding: .utf8) {
                    sendResponse(connection: connection, status: 200, body: body)
                } else {
                    sendResponse(connection: connection, status: 500, body: "{\"error\":\"encode\"}")
                }
            }
            log(["level": "info", "msg": "request_end", "path": path, "req_id": requestID, "status": 200, "duration_ms": Int(Date().timeIntervalSince(start) * 1000)])
        } catch {
            log(["level": "error", "msg": "generation failed", "model": genReq.model.displayName, "req_id": requestID, "error": "\(error)"])
            sendResponse(connection: connection, status: 500, body: "{\"error\":\"\(error)\"}")
            log(["level": "info", "msg": "request_end", "path": path, "req_id": requestID, "status": 500, "duration_ms": Int(Date().timeIntervalSince(start) * 1000)])
        }
    }

    private func sendStreamingResponse(connection: NWConnection, genReq: GenerationRequest, loaded: LoadedModel, runner: any ModelRunner, requestID: String, openAIResponse: Bool, openAIModel: String?, sse: Bool) {
        var cancelled = false
        connection.stateUpdateHandler = { state in
            switch state {
            case .failed, .cancelled:
                cancelled = true
            default:
                break
            }
        }

        let headers = [
            "HTTP/1.1 200 OK",
            "Content-Type: \(sse ? "text/event-stream" : "application/x-ndjson")",
            "Transfer-Encoding: chunked",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")
        connection.send(content: Data(headers.utf8), completion: .contentProcessed({ _ in }))

        Task {
            do {
                let start = Int(Date().timeIntervalSince1970)
                var generatedCount = 0
                for try await event in runner.generate(request: genReq, using: loaded) {
                    if cancelled { break }
                    let obj: [String: Any]
                    switch event {
                    case let .token(tok):
                        generatedCount += 1
                        if openAIResponse {
                            let chunk = OpenAIChatChunk(
                                id: "chatcmpl-\(requestID)",
                                object: "chat.completion.chunk",
                                created: start,
                                model: openAIModel ?? genReq.model.displayName,
                                choices: [
                                    OpenAIChatChunkChoice(
                                        index: 0,
                                        delta: OpenAIChatMessage(role: "assistant", content: tok),
                                        finishReason: nil
                                    )
                                ]
                            )
                            let data = try JSONEncoder().encode(chunk)
                            obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                        } else {
                            obj = ["token": tok]
                        }
                    case let .completed(res):
                        if openAIResponse {
                            let chunk = OpenAIChatChunk(
                                id: "chatcmpl-\(requestID)",
                                object: "chat.completion.chunk",
                                created: start,
                                model: openAIModel ?? genReq.model.displayName,
                                choices: [
                                    OpenAIChatChunkChoice(
                                        index: 0,
                                        delta: OpenAIChatMessage(role: "assistant", content: res.text),
                                        finishReason: "stop"
                                    )
                                ]
                            )
                            let data = try JSONEncoder().encode(chunk)
                            obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
                        } else {
                            obj = ["done": true, "response": res.text]
                        }
                    }
                    let data = try JSONSerialization.data(withJSONObject: obj, options: [])
                    let payload: Data = {
                        if sse {
                            return Data("data: ".utf8) + data + Data("\n\n".utf8)
                        } else {
                            return data + Data("\n".utf8)
                        }
                    }()
                    let chunkHeader = String(format: "%X\r\n", payload.count)
                    var chunk = Data(chunkHeader.utf8)
                    chunk.append(payload)
                    chunk.append(Data("\r\n".utf8))
                    connection.send(content: chunk, completion: .contentProcessed({ _ in }))
                }
                connection.send(content: Data("0\r\n\r\n".utf8), completion: .contentProcessed({ _ in connection.cancel() }))
            } catch {
                log(["level": "error", "msg": "streaming failed", "model": genReq.model.displayName, "req_id": requestID, "error": "\(error)"])
                connection.send(content: Data("0\r\n\r\n".utf8), completion: .contentProcessed({ _ in connection.cancel() }))
            }
        }
    }

    private func sendResponse(connection: NWConnection, status: Int, body: String) {
        let headers = [
            "HTTP/1.1 \(status) \(status == 200 ? "OK" : "ERR")",
            "Content-Type: application/json",
            "Content-Length: \(body.utf8.count)",
            "Connection: close",
            "",
            ""
        ].joined(separator: "\r\n")

        let responseData = Data((headers + body).utf8)
        connection.send(content: responseData, completion: .contentProcessed({ _ in
            connection.cancel()
        }))
    }
}
