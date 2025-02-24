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
                    let path = String(cString: pathsPointer[Int(i)])
                    
                    // Process the file event
                    observer.processFileEvent(flag: flag, path: path)
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
    
    private func processFileEvent(flag: UInt32, path: String) {
        // Check if this is a creation event
        let isCreated = (flag & UInt32(kFSEventStreamEventFlagItemRenamed)) != 0
        guard isCreated else { return }
        
        // Verify the file exists and is an image
        guard FileManager.default.fileExists(atPath: path) && isImageFile(path) else { return }
        
        // Handle HEIC files differently if conversion is enabled
        if isHEICFile(path) && UserDefaults.standard.bool(forKey: convertHEICKey) {
            handleHEICFile(at: path)
        } else {
            notifyDelegate(with: path)
        }
    }
    
    private func handleHEICFile(at path: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let jpgPath = self.convertHEICToJPG(heicPath: path) {
                self.notifyDelegate(with: jpgPath)
            } else {
                // Conversion failed, just notify of the original file
                self.notifyDelegate(with: path)
            }
        }
    }
    
    private func notifyDelegate(with path: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.directoryMonitor(self, didDetectNewImage: path)
        }
    }
    
    private func convertHEICToJPG(heicPath: String) -> String? {
        let heicURL = URL(fileURLWithPath: heicPath)
        let jpgPath = heicURL.deletingPathExtension().path + ".jpg"
        
        // Create the ImageMagick process
        let process = configureImageMagickProcess(inputPath: heicPath, outputPath: jpgPath)
        
        return executeConversion(process: process, outputPath: jpgPath)
    }
    
    private func configureImageMagickProcess(inputPath: String, outputPath: String) -> Process {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/magick")
        
        // Set the arguments with quality 80
        process.arguments = [
            "convert",
            inputPath,
            "-quality", "80",
            outputPath
        ]
        
        // Set up the pipes
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        
        return process
    }
    
    private func executeConversion(process: Process, outputPath: String) -> String? {
        let errorPipe = process.standardError as! Pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            // Check if the process was successful
            if process.terminationStatus == 0 && FileManager.default.fileExists(atPath: outputPath) {
                print("Successfully converted HEIC to JPG: \(outputPath)")
                return outputPath
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
