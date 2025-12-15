import Foundation
import ArgumentParser
import MLXInferenceKit
import ModelStoreKit

struct Serve: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "serve",
        abstract: "Run the mlxserve daemon (basic scaffold)"
    )

    enum RunnerKind: String, ExpressibleByArgument {
        case mock
        case local
        case python
        case swift
    }

    @Option(help: "Port to bind (default 11434).")
    var port: UInt16 = 11434

    @Option(help: "Model path mapping JSON (default: config/model-paths.local.json).")
    var modelPathsJson: String?

    @Option(help: "Runner to use: mock, local, python, or swift (default: python).")
    var runner: RunnerKind = .python

    @Option(help: "Python executable for the python runner.")
    var pythonPath: String?

    @Flag(help: "Disable MPS for the python runner (sets MLX_DISABLE_MPS=1 and MLX_DEVICE=cpu).")
    var disableMPS: Bool = false

    mutating func run() throws {
        let portValue = port
        let pathsJson = modelPathsJson
        let runnerKind = runner
        let pythonPathLocal = pythonPath
        let disableMPSFlag = disableMPS
        try runBlocking {
            let mapping: [ModelID: URL]
            if let json = pathsJson {
                mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: json))
            } else if FileManager.default.fileExists(atPath: "config/model-paths.local.json") {
                mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: "config/model-paths.local.json"))
            } else {
                throw ValidationError("Provide --model-paths-json or create config/model-paths.local.json")
            }

            let runner: any ModelRunner
            switch runnerKind {
            case .mock:
                runner = MockModelRunner(tokens: ["hello", "from", "mock", "runner"])
            case .local:
                runner = LocalMLXRunner(modelPaths: mapping)
            case .python:
                runner = PythonMLXLmRunner(
                    modelPaths: mapping,
                    pythonExecutable: PythonMLXLmRunner.resolvePythonExecutable(preferred: pythonPathLocal),
                    disableMPS: disableMPSFlag
                )
            case .swift:
                let adapter = MLXSwiftAdapter(
                    modelPaths: mapping,
                    placeholderTokens: [],
                    backend: .nativeSwift
                )
                runner = MLXRunner(adapter: adapter)
            }
            let store = try FileModelStore()
            let server = HTTPServer(port: portValue, runner: runner, store: store)
            try server.start()
        }
    }
}
