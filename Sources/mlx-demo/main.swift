import Foundation
import ArgumentParser
import MLXInferenceKit

@main
struct DemoCommand: AsyncParsableCommand {
    enum RunnerKind: String, ExpressibleByArgument {
        case mock
        case local
        case swift
    }

    @Option(name: .shortAndLong, help: "Prompt to send to the model.")
    var prompt: String

    @Option(name: .shortAndLong, help: "Model name (tag).")
    var model: String = "demo"

    @Option(name: .shortAndLong, help: "Tokens to stream back (used for mock runner).")
    var tokens: [String] = ["hello", " world", "!"]

    @Option(name: .long, help: "Path to a local model file (used with --runner local).")
    var modelPath: String?

    @Option(name: .long, help: "JSON file with model path mappings (used with --runner local).")
    var modelPathsJson: String?

    @Option(name: .long, help: "Use default config/model-paths.local.json if present (local runner).")
    var useDefaultMapping: Bool = true

    @Option(name: .long, help: "Runner type: mock or local.")
    var runner: RunnerKind = .mock

    mutating func run() async throws {
        let modelID = ModelID(name: model)
        let runnerInstance: any ModelRunner

        switch runner {
        case .mock:
            runnerInstance = MockModelRunner(tokens: tokens)
        case .local:
            let mapping: [ModelID: URL]
            if let jsonPath = modelPathsJson {
                mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: jsonPath))
            } else if let path = modelPath {
                mapping = [modelID: URL(fileURLWithPath: path)]
            } else if useDefaultMapping {
                let defaultPath = URL(fileURLWithPath: "config/model-paths.local.json")
                if FileManager.default.fileExists(atPath: defaultPath.path) {
                    mapping = try ModelPathResolver.load(from: defaultPath)
                } else {
                    throw ValidationError("Provide --model-path or --model-paths-json (default mapping not found)")
                }
            } else {
                throw ValidationError("Provide --model-path or --model-paths-json when using --runner local")
            }
            runnerInstance = LocalMLXRunner(modelPaths: mapping)
        case .swift:
            let mapping: [ModelID: URL]
            if let jsonPath = modelPathsJson {
                mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: jsonPath))
            } else if let path = modelPath {
                mapping = [modelID: URL(fileURLWithPath: path)]
            } else if useDefaultMapping {
                let defaultPath = URL(fileURLWithPath: "config/model-paths.local.json")
                if FileManager.default.fileExists(atPath: defaultPath.path) {
                    mapping = try ModelPathResolver.load(from: defaultPath)
                } else {
                    throw ValidationError("Provide --model-path or --model-paths-json (default mapping not found)")
                }
            } else {
                throw ValidationError("Provide --model-path or --model-paths-json when using --runner swift")
            }
            let adapter = MLXSwiftAdapter(
                modelPaths: mapping,
                placeholderTokens: [],
                backend: .nativeSwift
            )
            runnerInstance = MLXRunner(adapter: adapter)
        }

        let loaded = try await runnerInstance.load(model: modelID, options: ModelLoadOptions())
        let request = GenerationRequest(model: loaded.id, prompt: prompt)

        for try await event in runnerInstance.generate(request: request, using: loaded) {
            switch event {
            case let .token(token):
                FileHandle.standardOutput.write(Data(token.utf8))
                FileHandle.standardOutput.synchronizeFile()
            case let .completed(result):
                FileHandle.standardOutput.write(
                    Data("\n\n[done] \(result.stats.generatedTokenCount) tokens\n".utf8)
                )
            }
        }
    }
}
