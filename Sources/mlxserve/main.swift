import ArgumentParser
import MLXInferenceKit
import ModelStoreKit
import Foundation

@main
struct MLXServe: AsyncParsableCommand {
    @Option(name: .shortAndLong, help: "Port to bind (default 11434).")
    var port: UInt16 = 11434

    @Option(name: .long, help: "Model path mapping JSON (default: config/model-paths.local.json).")
    var modelPathsJson: String?

    func run() async throws {
        let mapping: [ModelID: URL]
        if let json = modelPathsJson {
            mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: json))
        } else if FileManager.default.fileExists(atPath: "config/model-paths.local.json") {
            mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: "config/model-paths.local.json"))
        } else {
            throw ValidationError("Provide --model-paths-json or create config/model-paths.local.json")
        }

        let adapter = MLXSwiftAdapter(
            modelPaths: mapping,
            placeholderTokens: [],
            backend: .nativeSwift
        )
        let runner = MLXRunner(adapter: adapter)
        let store = try FileModelStore()
        let server = HTTPServer(port: port, runner: runner, store: store)
        try server.start()
    }
}
