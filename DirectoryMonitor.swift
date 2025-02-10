import Foundation

class DirectoryMonitor {
    private var stream: FSEventStreamRef?
    private let path: String
    weak var delegate: DirectoryMonitorDelegate?
    
    init(path: String) {
        self.path = path
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        var context = FSEventStreamContext()
        context.version = 0
        context.info = Unmanaged.passRetained(self).toOpaque()
        context.retain = nil
        context.release = nil
        context.copyDescription = nil

        let pathsToWatch = [path] as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        
        let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
            autoreleasepool {
                guard let info = clientCallBackInfo else { return }
                let observer = Unmanaged<DirectoryMonitor>.fromOpaque(info).takeUnretainedValue()
                
                // Cast the raw pointer to a pointer to constant strings
                let pathsPointer = eventPaths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
                
                // Iterate through the paths
                for i in 0..<numEvents {
                    let flag = eventFlags[Int(i)]
                    
                    // Check if this is a creation event
                    let isCreated = (flag & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0
                    let path = String(cString: pathsPointer[Int(i)])
                  
                    if isCreated {
                        
                        // Verify the file exists and is an image
                        if FileManager.default.fileExists(atPath: path) && observer.isImageFile(path) {
                            DispatchQueue.main.async {
                                observer.delegate?.directoryMonitor(observer, didDetectNewImage: path)
                            }
                        }
                    }
                }
            }
        }

        stream = FSEventStreamCreate(kCFAllocatorDefault,
                                   callback,
                                   &context,
                                   pathsToWatch,
                                   FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                                   0,
                                   flags)
        
        if let stream = stream {
            FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
            FSEventStreamStart(stream)
        }
    }
    
    func stopMonitoring() {
        if let stream = stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }
    
    private func isImageFile(_ path: String) -> Bool {
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
        return imageExtensions.contains(URL(fileURLWithPath: path).pathExtension.lowercased())
    }
}
