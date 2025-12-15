import Foundation
import ArgumentParser
import ModelStoreKit
import MLXInferenceKit

@available(macOS 10.15, macCatalyst 13, iOS 13, tvOS 13, watchOS 6, *)
struct MLXCTL: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "mlxctl (store-focused scaffold)",
        subcommands: [Store.self, Spec.self, Pull.self, Run.self, Serve.self],
        defaultSubcommand: Run.self
    )
}

struct Store: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "store",
        abstract: "Manage local model manifests and blobs",
        subcommands: [List.self, Show.self, Remove.self, ImportBlob.self, Verify.self]
    )

    struct Options: ParsableArguments {
        @Option(help: "Root path for the model store (default: ~/.mlxollama or $MLXOLLAMA_HOME)")
        var root: String?

        func resolveStore() throws -> FileModelStore {
            if let root {
                return try FileModelStore(root: URL(fileURLWithPath: root, isDirectory: true))
            }
            return try FileModelStore()
        }
    }

    struct List: ParsableCommand {
        @OptionGroup var options: Options

        mutating func run() throws {
            let opts = options
            try runBlocking {
                let store = try opts.resolveStore()
                let manifests = try await store.list()
                for manifest in manifests {
                    let tag = manifest.tag.displayName
                    let size = manifest.sizeBytes
                    let digest = manifest.digest.value
                    print("\(tag)\t\(size) bytes\t\(digest)")
                }
            }
        }
    }

    struct Show: ParsableCommand {
        @OptionGroup var options: Options

        @Argument(help: "Model tag (e.g., name[:variant][@version])")
        var tagString: String

        mutating func run() throws {
            let opts = options
            let tagStr = tagString
            try runBlocking {
                guard let tag = ModelTag(string: tagStr) else {
                    throw ValidationError("Invalid tag format: \(tagStr)")
                }
                let store = try opts.resolveStore()
                guard let manifest = try await store.manifest(for: tag) else {
                    throw ValidationError("Tag not found: \(tag.displayName)")
                }
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let data = try encoder.encode(manifest)
                if let json = String(data: data, encoding: .utf8) {
                    print(json)
                } else {
                    print("Manifest decoded but could not render as UTF-8")
                }
            }
        }
    }

    struct Remove: ParsableCommand {
        @OptionGroup var options: Options

        @Argument(help: "Model tag (e.g., name[:variant][@version])")
        var tagString: String

        @Flag(help: "Delete blobs referenced by the manifest")
        var deleteBlobs: Bool = false

        mutating func run() throws {
            let opts = options
            let tagStr = tagString
            let shouldDelete = deleteBlobs
            try runBlocking {
                guard let tag = ModelTag(string: tagStr) else {
                    throw ValidationError("Invalid tag format: \(tagStr)")
                }
                let store = try opts.resolveStore()
                try await store.remove(tag: tag, deleteBlobs: shouldDelete)
                print("Removed \(tag.displayName)\(shouldDelete ? " (blobs deleted)" : "")")
            }
        }
    }

    struct ImportBlob: ParsableCommand {
        @OptionGroup var options: Options

        @Argument(help: "Path to blob file to import")
        var path: String

        mutating func run() throws {
            let opts = options
            let importPath = path
            try runBlocking {
                let store = try opts.resolveStore()
                let digest = try await store.importBlob(from: URL(fileURLWithPath: importPath))
                print("Imported blob with digest \(digest.algorithm.rawValue):\(digest.value)")
            }
        }
    }

    struct Verify: ParsableCommand {
        @OptionGroup var options: Options

        @Argument(help: "Model tag (e.g., name[:variant][@version])")
        var tagString: String

        mutating func run() throws {
            let opts = options
            let tagStr = tagString
            try runBlocking {
                guard let tag = ModelTag(string: tagStr) else {
                    throw ValidationError("Invalid tag format: \(tagStr)")
                }
                let store = try opts.resolveStore()
                guard let manifest = try await store.manifest(for: tag) else {
                    throw ValidationError("Tag not found: \(tag.displayName)")
                }
                let ok = try await store.verify(manifest: manifest)
                print(ok ? "Verified \(tag.displayName)" : "Verification failed for \(tag.displayName)")
            }
        }
    }
}

struct Spec: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "spec",
        abstract: "Inspect or validate a ModelSpec",
        subcommands: [Validate.self, Pack.self]
    )

    struct Validate: ParsableCommand {
        @Argument(help: "Path to ModelSpec JSON file")
        var path: String

        mutating func run() throws {
            let url = URL(fileURLWithPath: path)
            let spec = try ModelSpecLoader.load(from: url)
            print("Valid ModelSpec: \(spec.tag.displayName) format=\(spec.format) baseRepo=\(spec.base.hfRepo ?? spec.base.localPath ?? "n/a")")
        }
    }

    struct Pack: ParsableCommand {
        @Option(help: "Root path for the model store (default: ~/.mlxollama or $MLXOLLAMA_HOME)")
        var root: String?

        @Argument(help: "Path to ModelSpec JSON file")
        var specPath: String

        @Option(help: "Path to model artifact file to import")
        var artifact: String

        @Option(help: "Optional path to tokenizer file to import")
        var tokenizer: String?

        mutating func run() throws {
            let rootPath = root
            let specPathLocal = specPath
            let artifactPath = artifact
            let tokenizerPath = tokenizer
            try runBlocking {
                let store = try rootPath.map { try FileModelStore(root: URL(fileURLWithPath: $0, isDirectory: true)) } ?? FileModelStore()
                let spec = try ModelSpecLoader.load(from: URL(fileURLWithPath: specPathLocal))
                let builder = ModelSpecBuilder(store: store)
                let manifest = try await builder.build(
                    spec: spec,
                    options: ModelSpecBuildOptions(
                        artifactPath: URL(fileURLWithPath: artifactPath),
                        tokenizerPath: tokenizerPath.map { URL(fileURLWithPath: $0) }
                    )
                )
                print("Packed \(manifest.tag.displayName)")
                print("  artifact digest: \(manifest.digest.algorithm.rawValue):\(manifest.digest.value)")
                if let tok = manifest.additionalBlobs?["tokenizer"] {
                    print("  tokenizer digest: \(tok.algorithm.rawValue):\(tok.value)")
                }
            }
        }
    }
}

// Minimal pull/import command (local artifact → store manifest + blob)
struct Pull: ParsableCommand {
    @Option(help: "Root path for the model store (default: ~/.mlxollama or $MLXOLLAMA_HOME)")
    var root: String?

    @Argument(help: "Model tag (name[:variant][@version])")
    var tagString: String

    @Option(help: "Path to model artifact file to import")
    var artifact: String

    @Option(help: "Optional path to tokenizer file to import")
    var tokenizer: String?

    mutating func run() throws {
        let tagStr = tagString
        let rootPath = root
        let artifactPath = artifact
        let tokenizerPath = tokenizer
        try runBlocking {
            guard let tag = ModelTag(string: tagStr) else {
                throw ValidationError("Invalid tag format: \(tagStr)")
            }
            let store = try rootPath.map { try FileModelStore(root: URL(fileURLWithPath: $0, isDirectory: true)) } ?? FileModelStore()
            let artifactURL = URL(fileURLWithPath: artifactPath)
            let tokenizerURL = tokenizerPath.map { URL(fileURLWithPath: $0) }

            let builder = ModelSpecBuilder(store: store)
            let version = tag.version ?? "latest"
            let spec = ModelSpec(
                name: tag.name,
                version: version,
                base: ModelSpec.Base(hfRepo: nil, revision: nil, localPath: artifactURL.path),
                format: "mlx",
                quantization: tag.variant,
                tokenizer: tokenizerURL?.lastPathComponent,
                promptTemplate: nil,
                defaults: nil,
                license: nil,
                metadata: ["source": "local-import"]
            )
            let manifest = try await builder.build(
                spec: spec,
                options: ModelSpecBuildOptions(
                    artifactPath: artifactURL,
                    tokenizerPath: tokenizerURL
                )
            )
            print("Imported \(manifest.tag.displayName)")
            print("  artifact digest: \(manifest.digest.algorithm.rawValue):\(manifest.digest.value)")
            if let tok = manifest.additionalBlobs?["tokenizer"] {
                print("  tokenizer digest: \(tok.algorithm.rawValue):\(tok.value)")
            }
        }
    }
}

struct Run: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a one-off prompt against a local runner (mock/local)"
    )

    enum RunnerKind: String, ExpressibleByArgument {
        case mock
        case local
        case python
        case swift
    }

    @Option(name: .shortAndLong, help: "Prompt to send to the model.")
    var prompt: String

    @Option(name: .shortAndLong, help: "Model tag (name[:variant][@version]).")
    var model: String

    @Option(help: "Runner type: mock, local, python, or swift (Swift adapter using python backend).")
    var runner: RunnerKind = .mock

    @Option(help: "Path to model file (local runner).")
    var modelPath: String?

    @Option(help: "JSON file with model path mappings (local runner).")
    var modelPathsJson: String?

    @Option(help: "Token list for mock runner (comma-separated).")
    var tokens: String = "hello, world"

    @Option(help: "Python executable for --runner python (default: .venv/bin/python3 if present, else python3).")
    var pythonPath: String?

    @Flag(help: "Disable MPS for the python mlx-lm runner (sets MLX_DISABLE_MPS=1).")
    var disableMPS: Bool = false

    mutating func run() throws {
        let modelIDName = model
        let runnerKind = runner
        let modelPathLocal = modelPath
        let modelPathsJsonLocal = modelPathsJson
        let tokensLocal = tokens
        let pythonPathLocal = pythonPath
        let promptText = prompt
        let disableMPSFlag = disableMPS

        try runBlocking {
            let modelID = ModelID(name: modelIDName)
            let runnerInstance: any ModelRunner

            switch runnerKind {
            case .mock:
                let tokenList = tokensLocal.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
                runnerInstance = MockModelRunner(tokens: tokenList)
            case .local:
                let mapping: [ModelID: URL]
                if let jsonPath = modelPathsJsonLocal {
                    mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: jsonPath))
                } else if let path = modelPathLocal {
                    mapping = [modelID: URL(fileURLWithPath: path)]
                } else if FileManager.default.fileExists(atPath: "config/model-paths.local.json") {
                    mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: "config/model-paths.local.json"))
                } else {
                    throw ValidationError("Provide --model-path or --model-paths-json for local runner")
                }
                runnerInstance = LocalMLXRunner(modelPaths: mapping)
            case .python:
                let mapping: [ModelID: URL]
                if let jsonPath = modelPathsJsonLocal {
                    mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: jsonPath))
                } else if let path = modelPathLocal {
                    mapping = [modelID: URL(fileURLWithPath: path)]
                } else if FileManager.default.fileExists(atPath: "config/model-paths.local.json") {
                    mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: "config/model-paths.local.json"))
                } else {
                    throw ValidationError("Provide --model-path or --model-paths-json for python runner")
                }
                runnerInstance = PythonMLXLmRunner(
                    modelPaths: mapping,
                    pythonExecutable: PythonMLXLmRunner.resolvePythonExecutable(preferred: pythonPathLocal),
                    disableMPS: disableMPSFlag
                )
            case .swift:
                let mapping: [ModelID: URL]
                if let jsonPath = modelPathsJsonLocal {
                    mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: jsonPath))
                } else if let path = modelPathLocal {
                    mapping = [modelID: URL(fileURLWithPath: path)]
                } else if FileManager.default.fileExists(atPath: "config/model-paths.local.json") {
                    mapping = try ModelPathResolver.load(from: URL(fileURLWithPath: "config/model-paths.local.json"))
                } else {
                    throw ValidationError("Provide --model-path or --model-paths-json for swift runner")
                }
                let adapter = MLXSwiftAdapter(
                    modelPaths: mapping,
                    placeholderTokens: [],
                    backend: .nativeSwift
                )
                runnerInstance = MLXRunner(adapter: adapter)
            }

            let loaded = try await runnerInstance.load(model: modelID, options: ModelLoadOptions())
            let request = GenerationRequest(model: modelID, prompt: promptText)

            for try await event in runnerInstance.generate(request: request, using: loaded) {
                switch event {
                case let .token(tok):
                    FileHandle.standardOutput.write(Data(tok.utf8))
                    FileHandle.standardOutput.synchronizeFile()
                case let .completed(result):
                    FileHandle.standardOutput.write(Data("\n\n[done] \(result.stats.generatedTokenCount) tokens\n".utf8))
                }
            }
        }
    }
}

// Helper to run async code from sync command entrypoints.
func runBlocking(_ operation: @escaping () async throws -> Void) throws {
    let semaphore = DispatchSemaphore(value: 0)
    var capturedError: Error?
    Task {
        do {
            try await operation()
        } catch {
            capturedError = error
        }
        semaphore.signal()
    }
    semaphore.wait()
    if let error = capturedError {
        throw error
    }
}

// Explicit entrypoint for the executable target.
MLXCTL.main()
