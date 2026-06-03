import Foundation
import AVFoundation
import UserNotifications
import Flutter

@available(iOS 10.0, *)
public class SenzuDownloadManager: NSObject, AVAssetDownloadDelegate, URLSessionDownloadDelegate, UNUserNotificationCenterDelegate {
    
    public static let shared = SenzuDownloadManager()
    
    private var downloadCompleteTitle = "Таталт амжилттай"
    private var downloadCompleteBody = "Видеог офлайн горимд үзэх боломжтой боллоо."
    private var downloadFailedTitle = "Таталт амжилтгүй"
    private var downloadFailedBody = "Видеог татахад алдаа гарлаа."
    private var licenseExpiredTitle = "Лиценз дууссан"
    private var licenseExpiredBody = "Офлайн лицензийн хугацаа дууссан байна."
    
    public func setNotificationLocales(
        completeTitle: String, completeBody: String,
        failedTitle: String, failedBody: String,
        expiredTitle: String, expiredBody: String
    ) {
        if !completeTitle.isEmpty { downloadCompleteTitle = completeTitle }
        if !completeBody.isEmpty { downloadCompleteBody = completeBody }
        if !failedTitle.isEmpty { downloadFailedTitle = failedTitle }
        if !failedBody.isEmpty { downloadFailedBody = failedBody }
        if !expiredTitle.isEmpty { licenseExpiredTitle = expiredTitle }
        if !expiredBody.isEmpty { licenseExpiredBody = expiredBody }
    }
    
    private var hlsSession: AVAssetDownloadURLSession!
    private var mp4Session: URLSession!
    
    private var activeTasks: [String: URLSessionTask] = [:]
    private var taskIds: [URLSessionTask: String] = [:]
    
    public var eventSink: FlutterEventSink?
    
    private override init() {
        super.init()
        
        let hlsConfig = URLSessionConfiguration.background(withIdentifier: "dev.senzu.senzu_player.hls")
        hlsSession = AVAssetDownloadURLSession(
            configuration: hlsConfig,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )
        
        let mp4Config = URLSessionConfiguration.background(withIdentifier: "dev.senzu.senzu_player.mp4")
        mp4Session = URLSession(
            configuration: mp4Config,
            delegate: self,
            delegateQueue: OperationQueue.main
        )
        
        UNUserNotificationCenter.current().delegate = self
        requestNotificationPermission()
    }
    
    public func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("[SenzuDownloader] Notification permission granted")
            } else if let error = error {
                print("[SenzuDownloader] Notification permission error: \(error)")
            }
        }
    }
    
    public func startDownload(id: String, urlString: String, headers: [String: String], drmConfig: [String: Any], title: String) {
        guard let url = URL(string: urlString) else { return }
        
        if urlString.contains(".m3u8") {
            // HLS Downloader via AVAssetDownloadTask
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            guard let task = hlsSession.makeAssetDownloadTask(
                asset: asset,
                assetTitle: title,
                assetArtworkData: nil,
                options: nil
            ) else { return }
            
            activeTasks[id] = task
            taskIds[task] = id
            task.resume()
            
            sendProgressUpdate(id: id, progress: 0.0, status: "downloading")
        } else {
            // MP4/Progressive Downloader
            var request = URLRequest(url: url)
            for (key, val) in headers {
                request.setValue(val, forHTTPHeaderField: key)
            }
            
            let task = mp4Session.downloadTask(with: request)
            activeTasks[id] = task
            taskIds[task] = id
            task.resume()
            
            sendProgressUpdate(id: id, progress: 0.0, status: "downloading")
        }
    }
    
    public func pauseDownload(id: String) {
        if let task = activeTasks[id] {
            task.suspend()
            sendProgressUpdate(id: id, progress: -1.0, status: "paused")
        }
    }
    
    public func resumeDownload(id: String) {
        if let task = activeTasks[id] {
            task.resume()
            sendProgressUpdate(id: id, progress: -1.0, status: "downloading")
        }
    }
    
    public func cancelDownload(id: String) {
        if let task = activeTasks[id] {
            task.cancel()
            activeTasks.removeValue(forKey: id)
            taskIds.removeValue(forKey: task)
            sendProgressUpdate(id: id, progress: 0.0, status: "cancelled")
        }
    }
    
    public func deleteDownload(id: String) {
        cancelDownload(id: id)
    }
    
    public func notifyLicenseExpired(id: String, title: String) {
        let body = title.isEmpty ? licenseExpiredBody : "\"\(title)\" \(licenseExpiredBody)"
        sendNotification(title: licenseExpiredTitle, body: body)
    }
    
    // MARK: - Bookmark helpers

    /// Creates a persistent URL bookmark string in the form "bookmark:<base64>".
    /// Falls back to the absoluteString of the URL if bookmark creation fails.
    public static func makeBookmarkString(for url: URL) -> String {
        do {
            let data = try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            return "bookmark:\(data.base64EncodedString())"
        } catch {
            print("[SenzuDownloader] Could not create bookmark for \(url): \(error)")
            return url.absoluteString
        }
    }

    /// Resolves a bookmark string back to a file URL.
    /// Returns nil if the bookmark is stale or invalid.
    public static func resolveBookmark(_ bookmarkString: String) -> URL? {
        guard bookmarkString.hasPrefix("bookmark:") else { return nil }
        let base64 = String(bookmarkString.dropFirst("bookmark:".count))
        guard let data = Data(base64Encoded: base64) else {
            print("[SenzuDownloader] Invalid base64 bookmark data")
            return nil
        }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                print("[SenzuDownloader] Bookmark is stale for: \(url.path)")
            }
            return url
        } catch {
            print("[SenzuDownloader] Failed to resolve bookmark: \(error)")
            return nil
        }
    }
    
    // MARK: - Private helpers

    private func sendProgressUpdate(id: String, progress: Double, status: String, localPath: String? = nil, bytesDownloaded: Int64? = nil, totalBytes: Int64? = nil) {
        var map: [String: Any] = [
            "id": id,
            "progress": progress,
            "status": status
        ]
        if let path = localPath {
            map["localPath"] = path
        }
        if let bytesDownloaded = bytesDownloaded {
            map["bytesDownloaded"] = bytesDownloaded
        }
        if let totalBytes = totalBytes {
            map["totalBytes"] = totalBytes
        }
        
        DispatchQueue.main.async {
            self.eventSink?(map)
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }

    private func getDirectorySize(at url: URL) -> Int64 {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: []) else {
            return 0
        }
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                if let fileSize = resourceValues.fileSize {
                    totalSize += Int64(fileSize)
                }
            } catch {
                print("[SenzuDownloader] Error calculating file size: \(error)")
            }
        }
        return totalSize
    }

    // MARK: - UNUserNotificationCenterDelegate
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .list, .sound])
        } else {
            completionHandler([.alert, .sound])
        }
    }
    
    // MARK: - AVAssetDownloadDelegate
    
    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        guard let id = taskIds[assetDownloadTask] else { return }
        
        var percent: Double = 0.0
        for value in loadedTimeRanges {
            let loadedTimeRange = value.timeRangeValue
            if timeRangeExpectedToLoad.duration.seconds > 0 {
                percent += loadedTimeRange.duration.seconds / timeRangeExpectedToLoad.duration.seconds
            }
        }
        
        sendProgressUpdate(id: id, progress: percent * 100.0, status: "downloading")
    }
    
    public func urlSession(_ session: URLSession, assetDownloadTask: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = taskIds[assetDownloadTask] else { return }

        print("[SenzuDownloader] HLS download finished. Raw location: \(location.absoluteString)")

        // Store as a persistent bookmark so the URL survives sandbox UUID changes
        // and app updates/reinstalls. The "bookmark:" prefix signals the player
        // to resolve via NSURLBookmarkData instead of treating the string as a path.
        let bookmarkString = SenzuDownloadManager.makeBookmarkString(for: location)

        let totalSize = getDirectorySize(at: location)

        print("[SenzuDownloader] Stored localPath: \(bookmarkString.prefix(60))... Size: \(totalSize)")
        sendProgressUpdate(id: id, progress: 100.0, status: "completed", localPath: bookmarkString, totalBytes: totalSize)
        sendNotification(title: downloadCompleteTitle, body: downloadCompleteBody)
    }
    
    // MARK: - URLSessionDownloadDelegate  (MP4 / progressive)
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let id = taskIds[downloadTask] else { return }
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) * 100.0
            sendProgressUpdate(id: id, progress: progress, status: "downloading", bytesDownloaded: totalBytesWritten, totalBytes: totalBytesExpectedToWrite)
        }
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let id = taskIds[downloadTask] else { return }
        
        // Copy MP4 file to app's Caches directory (persists, but not backed-up)
        let fileManager = FileManager.default
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let destURL = cacheDir.appendingPathComponent("senzu_downloads/\(id)/video.mp4")
        
        do {
            try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            if fileManager.fileExists(atPath: destURL.path) {
                try fileManager.removeItem(at: destURL)
            }
            try fileManager.copyItem(at: location, to: destURL)
            
            // Get size of downloaded file
            let attributes = try fileManager.attributesOfItem(atPath: destURL.path)
            let fileSize = attributes[.size] as? Int64 ?? 0
            
            // For MP4 in Caches, store a bookmark for path persistence
            let bookmarkString = SenzuDownloadManager.makeBookmarkString(for: destURL)
            sendProgressUpdate(id: id, progress: 100.0, status: "completed", localPath: bookmarkString, bytesDownloaded: fileSize, totalBytes: fileSize)
            sendNotification(title: downloadCompleteTitle, body: downloadCompleteBody)
        } catch {
            print("[SenzuDownloader] Failed to save progressive file: \(error)")
            sendProgressUpdate(id: id, progress: 0.0, status: "failed")
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let id = taskIds[task] else { return }
        if let error = error {
            print("[SenzuDownloader] Task failed: \(error.localizedDescription)")
            sendProgressUpdate(id: id, progress: 0.0, status: "failed")
            let body = error.localizedDescription.isEmpty ? downloadFailedBody : "\(downloadFailedBody) \(error.localizedDescription)"
            sendNotification(title: downloadFailedTitle, body: body)
        }
        
        activeTasks.removeValue(forKey: id)
        taskIds.removeValue(forKey: task)
    }
}

// MARK: - Stream handler

public class SenzuDownloadStreamHandler: NSObject, FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        if #available(iOS 10.0, *) {
            SenzuDownloadManager.shared.eventSink = events
        }
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        if #available(iOS 10.0, *) {
            SenzuDownloadManager.shared.eventSink = nil
        }
        return nil
    }
}
