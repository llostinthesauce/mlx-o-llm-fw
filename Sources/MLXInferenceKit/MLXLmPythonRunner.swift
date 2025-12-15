import Foundation

public enum PythonRunnerError: Error, Equatable {
    case modelPathMissing(ModelID)
    case processFailed(String)
}

/// ModelRunner implementation that shells out to `mlx_lm` Python CLI to run generation.
/// This is a bridge until a native Swift MLX runner is wired.
public final class PythonMLXLmRunner: ModelRunner {
    private let modelPaths: [ModelID: URL]
    private let pythonExecutable: String
    private let generateScript: URL
    private let disableMPS: Bool
    private let allowFallback: Bool

    public init(
        modelPaths: [ModelID: URL],
        pythonExecutable: String = PythonMLXLmRunner.resolvePythonExecutable(),
        generateScript: URL = URL(fileURLWithPath: "upstream/mlx-lm/mlx_lm/generate.py"),
        disableMPS: Bool = false,
        allowFallback: Bool = true
    ) {
        self.modelPaths = modelPaths
        self.pythonExecutable = pythonExecutable
        self.generateScript = generateScript
        self.disableMPS = disableMPS
        self.allowFallback = allowFallback
    }

    public func load(model: ModelID, options: ModelLoadOptions) async throws -> LoadedModel {
        guard modelPaths[model] != nil else {
            throw PythonRunnerError.modelPathMissing(model)
        }
        return LoadedModel(id: model)
    }

    public func unload(model: LoadedModel) async {
        // nothing to unload for subprocess bridge
    }

    public func generate(
        request: GenerationRequest,
        using model: LoadedModel
    ) -> AsyncThrowingStream<GenerationEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                guard let modelPath = modelPaths[model.id] else {
                    continuation.finish(throwing: PythonRunnerError.modelPathMissing(model.id))
                    return
                }

                let prompt = request.prompt
                let baseArgs: [String] = [
                    "-m", "mlx_lm", "generate",
                    "--model", modelPath.path,
                    "--prompt", prompt
                ]

                let runProcess: (_ forceCPU: Bool) async throws -> (String, String, Int32, TimeInterval) = { [pythonExecutable = self.pythonExecutable, generateScript = self.generateScript, disableMPS = self.disableMPS] forceCPU in
                    var args = baseArgs
                    if let max = request.config.maxTokens {
                        args.append(contentsOf: ["--max-tokens", "\(max)"])
                    }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: pythonExecutable)
                    process.arguments = args
                    process.currentDirectoryURL = generateScript.deletingLastPathComponent().deletingLastPathComponent()
                    var env = ProcessInfo.processInfo.environment
                    if disableMPS || forceCPU {
                        env["MLX_DISABLE_MPS"] = "1"
                        env["MLX_DEVICE"] = "cpu"
                    }
                    process.environment = env

                    let pipe = Pipe()
                    let errPipe = Pipe()
                    process.standardOutput = pipe
                    process.standardError = errPipe

                    try process.run()

                    let outHandle = pipe.fileHandleForReading
                    let errHandle = errPipe.fileHandleForReading
                    let start = Date()

                    // Stream stdout using a serial queue to avoid concurrent mutation warnings.
                    let queue = DispatchQueue(label: "python-runner.stdout")
                    var aggregate = ""
                    outHandle.readabilityHandler = { file in
                        queue.async {
                            let data = file.availableData
                            if data.isEmpty { return }
                            if Task.isCancelled {
                                process.terminate()
                                continuation.finish(throwing: RunnerError.cancelled)
                                return
                            }
                            if let chunk = String(data: data, encoding: .utf8) {
                                aggregate.append(chunk)
                                continuation.yield(.token(chunk))
                            }
                        }
                    }

                    process.waitUntilExit()
                    let stderrData = try? errHandle.readToEnd()
                    let stderrText = stderrData.flatMap { String(data: $0, encoding: .utf8) } ?? ""
                    let duration = Date().timeIntervalSince(start)
                    return (aggregate, stderrText, process.terminationStatus, duration)
                }

                do {
                    let firstCPU = self.disableMPS
                    var attemptCPU = firstCPU

                    // First try (GPU unless disableMPS was requested)
                    var aggregate = ""
                    var stderr = ""
                    var status: Int32 = 0
                    var duration: TimeInterval = 0

                    let gpuAttempt: () async throws -> Void = {
                        (aggregate, stderr, status, duration) = try await runProcess(attemptCPU)
                    }

                    do {
                        try await gpuAttempt()
                    } catch {
                        // If GPU attempt crashed/aborted, retry on CPU if allowed.
                        if self.allowFallback && !attemptCPU {
                            attemptCPU = true
                            (aggregate, stderr, status, duration) = try await runProcess(true)
                        } else {
                            throw error
                        }
                    }

                    // Retry on CPU if GPU failed or stderr hints at Metal/NSException.
                    let gpuFailed = status != 0 || (!stderr.isEmpty && stderr.localizedCaseInsensitiveContains("NSRangeException"))
                    if gpuFailed, self.allowFallback, !attemptCPU {
                        attemptCPU = true
                        (aggregate, stderr, status, duration) = try await runProcess(true)
                    }

                    if status != 0 {
                        continuation.finish(throwing: PythonRunnerError.processFailed(stderr.isEmpty ? "exit \(status)" : stderr))
                        return
                    }

                    let stats = GenerationStats(
                        promptTokenCount: request.prompt.split(separator: " ").count,
                        generatedTokenCount: aggregate.split(whereSeparator: { $0.isWhitespace }).count,
                        duration: duration
                    )
                    continuation.yield(.completed(GenerationResult(text: aggregate.trimmingCharacters(in: .whitespacesAndNewlines), stats: stats)))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// Resolve a python executable to use for mlx-lm. Preference order:
    /// 1) `preferred` argument
    /// 2) `MLX_PYTHON` environment variable
    /// 3) repo-local `.venv/bin/python3`
    /// 4) `python3` on PATH
    public static func resolvePythonExecutable(preferred: String? = nil) -> String {
        if let preferred, !preferred.isEmpty {
            return preferred
        }
        if let env = ProcessInfo.processInfo.environment["MLX_PYTHON"], !env.isEmpty {
            return env
        }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let venv = cwd.appendingPathComponent(".venv/bin/python3", isDirectory: false)
        if FileManager.default.fileExists(atPath: venv.path) {
            return venv.path
        }
        return "python3"
    }
}

// The runner wraps subprocess execution and is used from async contexts; mark as unchecked sendable.
extension PythonMLXLmRunner: @unchecked Sendable {}
