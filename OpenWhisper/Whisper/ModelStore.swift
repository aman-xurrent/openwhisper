import Foundation
import Observation

protocol DownloadableAsset {
    var fileName: String { get }
    var downloadURL: URL { get }
}

@MainActor
@Observable
final class ModelStore {
    static let directoryName = "OpenWhisper/models"
    static let didChange = Notification.Name("com.amankumar.openwhisper.modelStoreDidChange")

    let directory: URL

    private(set) var presentFileNames: Set<String> = []
    private(set) var progressByFileName: [String: Double] = [:]
    private(set) var errorByFileName: [String: String] = [:]

    @ObservationIgnored
    private var downloaders: [String: ModelDownloader] = [:]

    nonisolated static func defaultDirectory() -> URL {
        let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return applicationSupport.appendingPathComponent(directoryName, isDirectory: true)
    }

    init(directory: URL = ModelStore.defaultDirectory()) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        refresh()
    }

    func fileURL(for asset: DownloadableAsset) -> URL {
        directory.appendingPathComponent(asset.fileName)
    }

    func isDownloaded(_ asset: DownloadableAsset) -> Bool {
        presentFileNames.contains(asset.fileName)
    }

    func isDownloading(_ asset: DownloadableAsset) -> Bool {
        progressByFileName[asset.fileName] != nil
    }

    func progress(for asset: DownloadableAsset) -> Double? {
        progressByFileName[asset.fileName]
    }

    func error(for asset: DownloadableAsset) -> String? {
        errorByFileName[asset.fileName]
    }

    func refresh() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        presentFileNames = Set(files.filter { !$0.hasSuffix(".part") })
        NotificationCenter.default.post(name: Self.didChange, object: self)
    }

    func download(_ asset: DownloadableAsset) {
        let fileName = asset.fileName
        guard !isDownloaded(asset), !isDownloading(asset) else { return }
        errorByFileName[fileName] = nil
        progressByFileName[fileName] = 0

        let downloader = ModelDownloader(
            destination: fileURL(for: asset),
            onProgress: { [weak self] fraction in
                Task { @MainActor in self?.progressByFileName[fileName] = fraction }
            },
            onFinish: { [weak self] result in
                Task { @MainActor in self?.finishDownload(of: fileName, result: result) }
            }
        )
        downloaders[fileName] = downloader
        downloader.start(url: asset.downloadURL)
        Log.models.info("Downloading \(fileName) from \(asset.downloadURL.absoluteString)")
    }

    func cancelDownload(_ asset: DownloadableAsset) {
        downloaders[asset.fileName]?.cancel()
        downloaders[asset.fileName] = nil
        progressByFileName[asset.fileName] = nil
    }

    func delete(_ asset: DownloadableAsset) throws {
        try FileManager.default.removeItem(at: fileURL(for: asset))
        refresh()
    }

    private func finishDownload(of fileName: String, result: Result<URL, Error>) {
        downloaders[fileName] = nil
        progressByFileName[fileName] = nil
        switch result {
        case .success:
            refresh()
            Log.models.info("Downloaded \(fileName)")
        case .failure(let error):
            errorByFileName[fileName] = error.localizedDescription
            Log.models.error("Download of \(fileName) failed: \(error.localizedDescription)")
        }
    }
}

final class ModelDownloader: NSObject, URLSessionDownloadDelegate {
    enum DownloadError: LocalizedError {
        case badStatus(Int)

        var errorDescription: String? {
            switch self {
            case .badStatus(let code): return "The server answered with HTTP \(code)."
            }
        }
    }

    private let destination: URL
    private let onProgress: (Double) -> Void
    private let onFinish: (Result<URL, Error>) -> Void
    private var task: URLSessionDownloadTask?
    private var didFinish = false

    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    init(destination: URL, onProgress: @escaping (Double) -> Void, onFinish: @escaping (Result<URL, Error>) -> Void) {
        self.destination = destination
        self.onProgress = onProgress
        self.onFinish = onFinish
    }

    func start(url: URL) {
        let downloadTask = session.downloadTask(with: url)
        task = downloadTask
        downloadTask.resume()
    }

    func cancel() {
        task?.cancel()
        session.invalidateAndCancel()
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        onProgress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let statusCode = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        guard statusCode == 200 else {
            finish(.failure(DownloadError.badStatus(statusCode)))
            return
        }
        do {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: location, to: destination)
            finish(.success(destination))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as NSError).code == NSURLErrorCancelled { return }
        finish(.failure(error))
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !didFinish else { return }
        didFinish = true
        session.finishTasksAndInvalidate()
        onFinish(result)
    }
}
