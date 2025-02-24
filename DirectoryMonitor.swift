import Foundation

class DirectoryMonitor {
    private var stream: FSEventStreamRef?
    private let path: String
    weak var delegate: DirectoryMonitorDelegate?
    private let convertHEICKey = "convertHEICToJPG"
    
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
                            // Check if it's a HEIC file and conversion is enabled
                            if observer.isHEICFile(path) && UserDefaults.standard.bool(forKey: observer.convertHEICKey) {
                                // Convert the file
                                DispatchQueue.global(qos: .userInitiated).async {
                                    if let jpgPath = observer.convertHEICToJPG(heicPath: path) {
                                        DispatchQueue.main.async {
                                            observer.delegate?.directoryMonitor(observer, didDetectNewImage: jpgPath)
                                        }
                                    } else {
                                        // Conversion failed, just notify of the original file
                                        DispatchQueue.main.async {
                                            observer.delegate?.directoryMonitor(observer, didDetectNewImage: path)
                                        }
                                    }
                                }
                            } else {
                                // Non-HEIC file or conversion disabled
                                DispatchQueue.main.async {
                                    observer.delegate?.directoryMonitor(observer, didDetectNewImage: path)
                                }
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
    
    func isHEICFile(_ path: String) -> Bool {
        return URL(fileURLWithPath: path).pathExtension.lowercased() == "heic"
    }
    
    func convertHEICToJPG(heicPath: String) -> String? {
        let heicURL = URL(fileURLWithPath: heicPath)
        let jpgPath = heicURL.deletingPathExtension().path + ".jpg"
        
        // Create a process to run the magick command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/magick")
        
        // Set the arguments with quality 80
        process.arguments = [
            "convert",
            heicPath,
            "-quality", "80",
            jpgPath
        ]
        
        // Set up the process
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Check if the process was successful
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: jpgPath) {
                print("Successfully converted HEIC to JPG: \(jpgPath)")
                return jpgPath
            } else {
                // Read the error output if conversion failed
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("Failed to convert HEIC to JPG. Error: \(errorMessage)")
                return nil
            }
        } catch {
            print("Failed to start conversion process: \(error.localizedDescription)")
            return nil
        }
    }
}
