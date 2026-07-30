import Foundation

enum ToolLocatorError: LocalizedError {
    case executablesMissing(names: [String], searchedPaths: [String: [URL]])
    case executableNotExecutable(name: String, url: URL)
    case fallbackExecutableMissing(name: String)
    case fallbackExecutableNotExecutable(name: String, url: URL)

    var errorDescription: String? {
        switch self {
        case .executablesMissing(let names, let searchedPaths):
            let toolList = names.joined(separator: ", ")

            let searchDetails = names.compactMap { name -> String? in
                guard let paths = searchedPaths[name], !paths.isEmpty else { return nil }
                let joined = paths.map(\.path).joined(separator: "\n")
                return "\(name):\n\(joined)"
            }.joined(separator: "\n\n")

            if searchDetails.isEmpty {
                return "Missing executable(s): \(toolList)"
            }

            return """
            Missing executable(s): \(toolList)

            Searched:
            \(searchDetails)
            """

        case .executableNotExecutable(let name, let url):
            return "Bundled \(name) executable is not usable: \(url.path)"

        case .fallbackExecutableMissing(let name):
            return "Development fallback executable not found in PATH: \(name)"

        case .fallbackExecutableNotExecutable(let name, let url):
            return "Development fallback \(name) executable is not usable: \(url.path)"
        }
    }
}

enum ToolLocator {
    static let ffmpegName = "ffmpeg"
    static let ffprobeName = "ffprobe"

    private static let lock = NSLock()
    private static var cachedURLs: [String: URL] = [:]

    private static let versionCacheLock = NSLock()
    private static var cachedVersionEntries: [String: String] = [:]
    private static var didLoadVersionEntries = false

    static func ffmpegURL() throws -> URL {
        try executableURL(named: ffmpegName)
    }

    static func ffprobeURL() throws -> URL {
        try executableURL(named: ffprobeName)
    }

    static func validateBundledToolsExist() throws {
        var missing: [String] = []
        var searchedPaths: [String: [URL]] = [:]

        for toolName in [ffmpegName, ffprobeName] {
            do {
                _ = try executableURL(named: toolName)
            } catch let error as ToolLocatorError {
                switch error {
                case .executablesMissing(let names, let paths):
                    missing.append(contentsOf: names)
                    for (name, value) in paths {
                        searchedPaths[name] = value
                    }

                case .executableNotExecutable(let name, _):
                    missing.append(name)
                    searchedPaths[name] = bundledSearchPaths(named: name)

                case .fallbackExecutableMissing(let name):
                    missing.append(name)
                    searchedPaths[name] = bundledSearchPaths(named: name)

                case .fallbackExecutableNotExecutable(let name, _):
                    missing.append(name)
                    searchedPaths[name] = bundledSearchPaths(named: name)
                }
            } catch {
                missing.append(toolName)
                searchedPaths[toolName] = bundledSearchPaths(named: toolName)
            }
        }

        let uniqueMissing = Array(Set(missing)).sorted()
        guard !uniqueMissing.isEmpty else { return }

        throw ToolLocatorError.executablesMissing(names: uniqueMissing, searchedPaths: searchedPaths)
    }

    static var ffmpegVersion: String {
        versionValue(for: ffmpegName)
    }

    static var ffprobeVersion: String {
        versionValue(for: ffprobeName)
    }

    static var isUsingBundledTools: Bool {
        isBundledExecutableAvailable(named: ffmpegName) && isBundledExecutableAvailable(named: ffprobeName)
    }

    // MARK: - Private

    private static func executableURL(named name: String) throws -> URL {
        lock.lock()
        if let cached = cachedURLs[name] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        if let bundled = bundledExecutableURL(named: name) {
            try validateExecutable(at: bundled, name: name, isFallback: false)
            cache(url: bundled, for: name)
            return bundled
        }

        #if DEBUG
        if let fallback = pathExecutableURL(named: name) {
            try validateExecutable(at: fallback, name: name, isFallback: true)
            cache(url: fallback, for: name)
            return fallback
        }
        #endif

        let searchedPaths = bundledSearchPaths(named: name)
        throw ToolLocatorError.executablesMissing(names: [name], searchedPaths: [name: searchedPaths])
    }

    private static func cache(url: URL, for name: String) {
        lock.lock()
        cachedURLs[name] = url
        lock.unlock()
    }

    private static func bundledExecutableURL(named name: String) -> URL? {
        let candidates = bundledSearchPaths(named: name)

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        return nil
    }

    private static func isBundledExecutableAvailable(named name: String) -> Bool {
        guard let url = bundledExecutableURL(named: name) else { return false }
        return FileManager.default.isExecutableFile(atPath: url.path)
    }

    private static func bundledSearchPaths(named name: String) -> [URL] {
        guard let resources = Bundle.main.resourceURL else { return [] }

        return [
            // Current Xcode packaging
            resources.appendingPathComponent(name),

            // Legacy layout kept for compatibility
            resources.appendingPathComponent("FFmpeg").appendingPathComponent(name)
        ]
    }

    private static func versionValue(for name: String) -> String {
        let entries = versionEntries()

        if let exact = entries[name.lowercased()], !exact.isEmpty {
            return exact
        }

        if let fallback = entries["default"], !fallback.isEmpty {
            return fallback
        }

        return "Unknown"
    }

    private static func versionEntries() -> [String: String] {
        versionCacheLock.lock()
        defer { versionCacheLock.unlock() }

        if didLoadVersionEntries {
            return cachedVersionEntries
        }

        let entries = loadVersionEntries()
        cachedVersionEntries = entries
        didLoadVersionEntries = true
        return entries
    }

    private static func loadVersionEntries() -> [String: String] {
        guard let contents = versionFileContents() else { return [:] }

        var entries: [String: String] = [:]

        let lines = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if lines.count == 1, !lines[0].contains(":") {
            entries["default"] = normalizeVersionString(lines[0])
            return entries
        }

        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let value = normalizeVersionString(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))

            if key.contains("ffmpeg") {
                entries[ffmpegName] = value
            } else if key.contains("ffprobe") {
                entries[ffprobeName] = value
            } else if entries["default"] == nil {
                entries["default"] = value
            }
        }

        return entries
    }

    private static func versionFileContents() -> String? {
        guard let resources = Bundle.main.resourceURL else { return nil }

        let candidates = [
            resources.appendingPathComponent("VERSION"),
            resources.appendingPathComponent("FFmpeg").appendingPathComponent("VERSION")
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return try? String(contentsOf: candidate, encoding: .utf8)
        }

        return nil
    }

    private static func normalizeVersionString(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }

        let patterns = [
            #"(?i)version\s+([0-9]+(?:\.[0-9]+)*)"#,
            #"([0-9]+(?:\.[0-9]+)+)"#,
            #"([0-9]+)"#
        ]

        for pattern in patterns {
            if let match = trimmed.range(of: pattern, options: .regularExpression) {
                let matched = String(trimmed[match])

                if pattern.contains("version") {
                    if let versionMatch = matched.range(of: #"([0-9]+(?:\.[0-9]+)*)"#, options: .regularExpression) {
                        return String(matched[versionMatch])
                    }
                } else {
                    return matched
                }
            }
        }

        return trimmed
    }

    #if DEBUG
    private static func pathExecutableURL(named name: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let output, !output.isEmpty else { return nil }
            return URL(fileURLWithPath: output)
        } catch {
            return nil
        }
    }
    #endif

    private static func validateExecutable(at url: URL, name: String, isFallback: Bool) throws {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

        guard exists, !isDirectory.boolValue else {
            if isFallback {
                throw ToolLocatorError.fallbackExecutableMissing(name: name)
            } else {
                throw ToolLocatorError.executableNotExecutable(name: name, url: url)
            }
        }

        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            if isFallback {
                throw ToolLocatorError.fallbackExecutableNotExecutable(name: name, url: url)
            } else {
                throw ToolLocatorError.executableNotExecutable(name: name, url: url)
            }
        }
    }
}
