import Foundation
import MathBlitzCore

/// Downloads the lesson bank and videos from the public GitHub Pages site and
/// keeps them on disk, so a lesson already fetched plays with no network.
/// Nothing is ever uploaded: there is no account, no analytics and no ad SDK,
/// which is what keeps the app out of COPPA's data-collection rules.
actor ContentStore {
    static let contentBase = URL(string: "https://ldyerstarks.github.io/math-blitz/")!

    enum StoreError: Error, LocalizedError {
        case offlineAndEmpty
        case badBank

        var errorDescription: String? {
            switch self {
            case .offlineAndEmpty: return "No lessons downloaded yet. Connect to Wi-Fi once and they'll be saved for later."
            case .badBank: return "That lesson pack didn't look right, so it wasn't used."
            }
        }
    }

    private let session: URLSession
    private let fileManager = FileManager.default

    init(session: URLSession = .shared) {
        self.session = session
    }

    private var root: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MathBlitz", isDirectory: true)
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private var bankFile: URL { root.appendingPathComponent("bank.json") }
    private var videoDirectory: URL {
        let dir = root.appendingPathComponent("videos", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Cached bank first so the app opens instantly, then refresh in the background.
    func cachedBank() -> LessonBank? {
        guard let data = try? Data(contentsOf: bankFile) else { return nil }
        return try? JSONDecoder().decode(LessonBank.self, from: data)
    }

    @discardableResult
    func refreshBank() async throws -> LessonBank {
        let url = Self.contentBase.appendingPathComponent("bank.json")
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let cached = cachedBank() { return cached }
            throw StoreError.offlineAndEmpty
        }
        guard let bank = try? JSONDecoder().decode(LessonBank.self, from: data),
              !bank.lessons.isEmpty, bank.malformed.isEmpty else {
            if let cached = cachedBank() { return cached }
            throw StoreError.badBank
        }
        try? data.write(to: bankFile, options: .atomic)
        return bank
    }

    func localVideoURL(for lesson: Lesson) -> URL? {
        let file = videoDirectory.appendingPathComponent(Self.fileName(for: lesson.video))
        return fileManager.fileExists(atPath: file.path) ? file : nil
    }

    /// A local copy if we have one, otherwise stream from the site while saving it.
    func videoURL(for lesson: Lesson) async -> URL {
        if let local = localVideoURL(for: lesson) { return local }
        let remote = Self.contentBase.appendingPathComponent(lesson.video)
        Task { try? await download(lesson) }
        return remote
    }

    func download(_ lesson: Lesson) async throws {
        let target = videoDirectory.appendingPathComponent(Self.fileName(for: lesson.video))
        guard !fileManager.fileExists(atPath: target.path) else { return }
        let remote = Self.contentBase.appendingPathComponent(lesson.video)
        let (temp, response) = try await session.download(from: remote)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
        try? fileManager.removeItem(at: target)
        try fileManager.moveItem(at: temp, to: target)
    }

    /// Keep the most recent videos and drop the rest, so the app never grows without bound.
    func pruneVideos(keeping keep: Set<String>, limit: Int = 12) {
        let wanted = Set(keep.map(Self.fileName(for:)))
        guard let files = try? fileManager.contentsOfDirectory(at: videoDirectory,
                                                               includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let disposable = files.filter { !wanted.contains($0.lastPathComponent) }
            .sorted { a, b in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
        for file in disposable.dropFirst(max(0, limit - wanted.count)) {
            try? fileManager.removeItem(at: file)
        }
    }

    func cacheSizeBytes() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(at: videoDirectory,
                                                               includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { total, file in
            total + Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
    }

    func clearVideos() {
        try? fileManager.removeItem(at: videoDirectory)
    }

    static func fileName(for path: String) -> String {
        path.replacingOccurrences(of: "/", with: "_")
    }
}
