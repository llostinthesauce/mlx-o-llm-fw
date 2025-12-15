// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MLXOllama",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "MLXInferenceKit", targets: ["MLXInferenceKit"]),
        .library(name: "ModelStoreKit", targets: ["ModelStoreKit"]),
        .executable(name: "mlx-demo", targets: ["mlx-demo"]),
        .executable(name: "mlxctl", targets: ["mlxctl"]),
        .executable(name: "mlxserve", targets: ["mlxserve"])
    ],
    dependencies: [
        .package(path: "upstream/swift-argument-parser"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", branch: "main"),
        .package(url: "https://github.com/ml-explore/mlx-swift.git", .upToNextMinor(from: "0.29.1")),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", branch: "main")
    ],
    targets: [
        .target(
            name: "MLXInferenceKit",
            dependencies: [
                "ModelStoreKit",
                .product(name: "Tokenizers", package: "swift-transformers"),
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-lm"),
                .product(name: "MLXLMCommon", package: "mlx-swift-lm")
            ]
        ),
        .target(name: "ModelStoreKit"),
        .executableTarget(
            name: "mlx-demo",
            dependencies: [
                "MLXInferenceKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "mlxctl",
            dependencies: [
                "MLXInferenceKit",
                "ModelStoreKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "mlxserve",
            dependencies: [
                "MLXInferenceKit",
                "ModelStoreKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "MLXInferenceKitTests",
            dependencies: ["MLXInferenceKit"]
        ),
        .testTarget(
            name: "ModelStoreKitTests",
            dependencies: ["ModelStoreKit"]
        )
    ]
)
