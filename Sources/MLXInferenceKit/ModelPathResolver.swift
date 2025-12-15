import Foundation

public struct ModelPathEntry: Codable {
    public let name: String
    public let variant: String?
    public let version: String?
    public let path: String
}

public enum ModelPathResolverError: Error, Equatable {
    case fileNotFound(URL)
    case invalidData(String)
}

/// Utility to load ModelID → URL mappings from a simple JSON file.
/// File format: array of objects with { "name": "...", "variant": "...", "version": "...", "path": "/path/to/model" }
public enum ModelPathResolver {
    public static func load(from url: URL) throws -> [ModelID: URL] {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ModelPathResolverError.fileNotFound(url)
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()

        do {
            let entries = try decoder.decode([ModelPathEntry].self, from: data)
            return Dictionary(uniqueKeysWithValues: entries.map { entry in
                let id = ModelID(name: entry.name, variant: entry.variant, version: entry.version)
                return (id, URL(fileURLWithPath: entry.path))
            })
        } catch {
            throw ModelPathResolverError.invalidData(error.localizedDescription)
        }
    }
}
