# MLXOllama

> [!WARNING]  
> **Work in Progress**  
> This project is currently under active development. Features, APIs, and documentation are subject to change effectively immediately. Use with caution.

MLXOllama is a Swift-based framework designed to bring the power of Large Language Models (LLMs) to Apple Silicon using the [MLX](https://github.com/ml-explore/mlx-swift) framework. It aims to provide a robust set of tools for inference, model management, and serving LLMs locally on macOS.

## Overview

This project is structured as a Swift Package containing several libraries and executables:

*   **Libraries:**
    *   `MLXInferenceKit`: The core engine for running LLM inference using MLX.
    *   `ModelStoreKit`: Handles model management, downloading, and storage (likely compatible with Hugging Face Hub).

*   **Executables:**
    *   `mlxctl`: A command-line interface for controlling and interacting with the framework.
    *   `mlxserve`: A server application to expose LLM capabilities via an API.
    *   `mlx-demo`: A demonstration app to showcase the framework's capabilities.

## Prerequisites

*   **macOS 14.0+** (Sonoma or later)
*   **Xcode 15+** (for building from source)
*   **Swift 5.9+**

## Installation & Setup

1.  **Clone the repository:**

    ```bash
    git clone https://github.com/llostinthesauce/mlx-o-llm-fw.git
    cd mlx-o-llm-fw
    ```

2.  **Bootstrap Dependencies:**

    This project relies on several upstream repositories. Run the bootstrap script to fetch them:

    ```bash
    ./bootstrap_upstreams.sh
    ```
    
    This script creates an `upstream` directory and populates it with necessary dependencies like `ollama`, `mlx-swift`, and others.

3.  **Build the Project:**

    You can build the project using Swift Package Manager:

    ```bash
    swift build
    ```

## Usage

### Running the CLI (`mlxctl`)

To run the command-line tool:

```bash
swift run mlxctl --help
```

### Running the Server (`mlxserve`)

To start the inference server:

```bash
swift run mlxserve --help
```

## Dependencies

This project leverages several powerful open-source libraries:

*   [**mlx-swift**](https://github.com/ml-explore/mlx-swift): Array framework for Apple Silicon.
*   [**mlx-swift-lm**](https://github.com/ml-explore/mlx-swift-lm): specialized LLM support for MLX.
*   [**swift-transformers**](https://github.com/huggingface/swift-transformers): Tokenizers and transformer models utilities.
*   [**swift-argument-parser**](https://github.com/apple/swift-argument-parser): Argument parsing for CLI tools.
*   **Ollama Source**: Portions of the codebase may reference or be inspired by Ollama's architecture.

## License

Please check the repository for license information.

---
*Last Updated: December 2025*
