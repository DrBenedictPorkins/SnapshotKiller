import Cocoa
import UserNotifications

@main
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: NSStatusItem!
    private var folderMonitor: DirectoryMonitor?
    private var scheduledDeletions: [String: Timer] = [:]
    private var monitoredFolderURL: URL?  // Real Desktop URL
    private var containerDesktopURL: URL?  // Sandboxed Desktop URL
    private var monitoredPathItem: NSMenuItem!  // Menu item to show current path
    private let lastMonitoredPathKey = "lastMonitoredPath"
    private let notifyOnDeletionKey = "notifyOnDeletion"  // New key for the setting
    private let convertHEICKey = "convertHEICToJPG"  // Key for HEIC to JPG conversion setting
    
    // Add this to create the application programmatically
    static func main() {
        let delegate = AppDelegate()
        let app = NSApplication.shared
        app.delegate = delegate
        app.run()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default value for notify on deletion if not set
        if UserDefaults.standard.object(forKey: notifyOnDeletionKey) == nil {
            UserDefaults.standard.set(true, forKey: notifyOnDeletionKey)  // Default to true
        }
        
        // Set default value for HEIC conversion if not set
        if UserDefaults.standard.object(forKey: convertHEICKey) == nil {
            UserDefaults.standard.set(false, forKey: convertHEICKey)  // Default to false
        }
        
        // Set the delegate first
        UNUserNotificationCenter.current().delegate = self
        
        // Request notification permissions with completion handler
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied: \(error?.localizedDescription ?? "No error")")
            }
        }
        
        // Hide dock icon programmatically
        NSApp.setActivationPolicy(.accessory)
        
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "folder.badge.gearshape", accessibilityDescription: "Monitor Folder")
        }
        
        setupMenu()
        
        // Get sandboxed Desktop path
        if let containerDesktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            self.containerDesktopURL = containerDesktopURL
        }
        
        // Try to restore last monitored path, or default to Desktop
        if let savedPath = UserDefaults.standard.string(forKey: lastMonitoredPathKey),
           let savedURL = URL(string: savedPath),
           FileManager.default.fileExists(atPath: savedURL.path) {
            // Found a saved path and it exists
            self.monitoredFolderURL = savedURL
            print("Restored monitoring to saved path: \(savedURL.path)")
        } else {
            // No saved path or it doesn't exist, default to Desktop
            let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
            let realDesktopURL = homeDirectory.appendingPathComponent("Desktop")
            self.monitoredFolderURL = realDesktopURL
            print("Defaulting to Desktop path: \(realDesktopURL.path)")
        }
        
        // Start monitoring the selected path
        if let monitoredURL = self.monitoredFolderURL {
            startMonitoring(url: monitoredURL)
        }
    }
    
    func setupMenu() {
        let menu = NSMenu()
        
        // Add monitored path display item (disabled, just for display)
        monitoredPathItem = NSMenuItem(title: "Monitoring: None", action: nil, keyEquivalent: "")
        monitoredPathItem.isEnabled = false
        menu.addItem(monitoredPathItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add other menu items
        menu.addItem(NSMenuItem(title: "Choose Folder...", action: #selector(chooseFolder(_:)), keyEquivalent: "o"))
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        // Add notification checkbox
        let notifyItem = NSMenuItem(title: "Notify on deletion", action: #selector(toggleNotifyOnDeletion(_:)), keyEquivalent: "")
        notifyItem.state = UserDefaults.standard.bool(forKey: notifyOnDeletionKey) ? .on : .off
        menu.addItem(notifyItem)
        
        // Add HEIC conversion checkbox
        let convertItem = NSMenuItem(title: "Convert HEIC to JPG", action: #selector(toggleConvertHEIC(_:)), keyEquivalent: "")
        convertItem.state = UserDefaults.standard.bool(forKey: convertHEICKey) ? .on : .off
        menu.addItem(convertItem)
        
        // Add separator
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc func toggleNotifyOnDeletion(_ sender: NSMenuItem) {
        // Toggle the state
        sender.state = sender.state == .on ? .off : .on
        
        // Save the new state
        UserDefaults.standard.set(sender.state == .on, forKey: notifyOnDeletionKey)
        UserDefaults.standard.synchronize()
    }
    
    @objc func toggleConvertHEIC(_ sender: NSMenuItem) {
        // Toggle the state
        sender.state = sender.state == .on ? .off : .on
        
        // Save the new state
        UserDefaults.standard.set(sender.state == .on, forKey: convertHEICKey)
        UserDefaults.standard.synchronize()
        
        // Check if ImageMagick is installed
        if sender.state == .on {
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: "/usr/local/bin/magick") {
                let alert = NSAlert()
                alert.messageText = "ImageMagick Not Found"
                alert.informativeText = "HEIC conversion requires ImageMagick to be installed at /usr/local/bin/magick. Please install it using Homebrew with:\n\nbrew install imagemagick"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                
                DispatchQueue.main.async {
                    alert.runModal()
                    // Turn off the setting since ImageMagick isn't available
                    sender.state = .off
                    UserDefaults.standard.set(false, forKey: self.convertHEICKey)
                    UserDefaults.standard.synchronize()
                }
            }
        }
    }
    
    private func updateMonitoredPathDisplay() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let monitoredURL = self.monitoredFolderURL {
                // Get the last two components of the path for a cleaner display
                let pathComponents = monitoredURL.pathComponents
                let displayPath: String
                if pathComponents.count >= 2 {
                    displayPath = pathComponents.suffix(2).joined(separator: "/")
                } else {
                    displayPath = monitoredURL.lastPathComponent
                }
                self.monitoredPathItem.title = "Monitoring: \(displayPath)"
            } else {
                self.monitoredPathItem.title = "Monitoring: None"
            }
        }
    }
    
    @objc func chooseFolder(_ sender: Any?) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        openPanel.begin { [weak self] response in
            if response == .OK, let url = openPanel.url {
                self?.monitoredFolderURL = url
                print("Changed monitoring to folder: \(url.path)")
                
                // Save the selected path
                UserDefaults.standard.set(url.absoluteString, forKey: self?.lastMonitoredPathKey ?? "")
                UserDefaults.standard.synchronize()
                
                self?.startMonitoring(url: url)
                self?.updateMonitoredPathDisplay()
                
                // Create and show notification
                let content = UNMutableNotificationContent()
                content.title = "Monitoring Location Changed"
                content.body = "Now monitoring: \(url.lastPathComponent)"
                content.sound = .default
                
                // Create and add notification request
                let request = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil  // nil trigger means show immediately
                )
                
                // Show the notification
                DispatchQueue.main.async {
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("Error showing notification: \(error)")
                        } else {
                            print("Notification request added successfully")
                        }
                    }
                }
            }
        }
    }
    
    func startMonitoring(url: URL) {
        folderMonitor?.stopMonitoring()
        folderMonitor = DirectoryMonitor(path: url.path)
        folderMonitor?.delegate = self
        folderMonitor?.startMonitoring()
        updateMonitoredPathDisplay()
    }
    
    private func showDeletionNotification(fileName: String) {
        // Check if notifications are enabled
        guard UserDefaults.standard.bool(forKey: notifyOnDeletionKey) else {
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = "File Deleted"
        content.body = "Successfully deleted '\(fileName)'"
        content.sound = .default
        
        // Create a trigger that will fire immediately but keep the notification for 3 seconds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing deletion notification: \(error)")
            }
        }
    }
    
    private func scheduleFileDeletion(filePath: String, after seconds: TimeInterval) {
        // Cancel any existing timer for this file
        scheduledDeletions[filePath]?.invalidate()
        
        // Create URL from file path
        let fileURL = URL(fileURLWithPath: filePath)
        print("Scheduling deletion for file: \(fileURL.path)")  // Debug print
        
        // Schedule new deletion
        let timer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            self?.deleteFile(at: fileURL)
        }
        
        scheduledDeletions[filePath] = timer
    }
    
    private func deleteFile(at fileURL: URL) {
        guard let monitoredFolder = monitoredFolderURL,
              let containerFolder = containerDesktopURL else {
            print("No monitored folder set")
            return
        }
        
        // Debug prints
        print("Attempting to delete file: \(fileURL.path)")
        print("Monitored folder: \(monitoredFolder.path)")
        print("Container folder: \(containerFolder.path)")
        
        // Convert the file path from real path to container path
        let fileName = fileURL.lastPathComponent
        let containerFileURL = containerFolder.appendingPathComponent(fileName)
        
        print("Converting file path:")
        print("From: \(fileURL.path)")
        print("To: \(containerFileURL.path)")
        
        do {
            // Try to delete the file using the container path
            try FileManager.default.removeItem(at: containerFileURL)
            print("Successfully deleted file: \(containerFileURL.lastPathComponent)")
            scheduledDeletions.removeValue(forKey: fileURL.path)
            
            // Show success notification
            showDeletionNotification(fileName: fileName)
            
        } catch {
            print("Delete attempt failed: \(error)")
            
            // Try deleting with the original path as fallback
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("Successfully deleted file using original path: \(fileURL.lastPathComponent)")
                scheduledDeletions.removeValue(forKey: fileURL.path)
                
                // Show success notification
                showDeletionNotification(fileName: fileName)
                
            } catch {
                print("Both delete attempts failed: \(error)")
                self.showDeleteError(error)
            }
        }
    }
    
    private func showDeleteError(_ error: Error) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Error Deleting File"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    // Handle notification actions
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              didReceive response: UNNotificationResponse,
                              withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let filePath = response.notification.request.content.userInfo["filePath"] as? String else {
            print("Error: No file path found in notification")
            completionHandler()
            return
        }
        
        // Match the action identifier to our enum
        let identifier = response.actionIdentifier
        
        if identifier.hasPrefix("delete") {
            if let seconds = getDeleteTimeFromIdentifier(identifier) {
                scheduleFileDeletion(filePath: filePath, after: TimeInterval(seconds))
            } else {
                print("Unknown delete time in identifier: \(identifier)")
            }
        } else {
            print("Unknown action identifier: \(identifier)")
        }
        
        completionHandler()
    }
    
    private func getDeleteTimeFromIdentifier(_ identifier: String) -> Int? {
        // Extract the numeric part from identifiers like "delete10", "delete30", etc.
        let numericPart = identifier.replacingOccurrences(of: "delete", with: "")
        return Int(numericPart)
    }
    
    // Allow notifications to be shown when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                              willPresent notification: UNNotification,
                              withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .list])
        } else {
            completionHandler([.alert, .sound])
        }
    }
}

extension AppDelegate: DirectoryMonitorDelegate {
    // Deletion time options in seconds
    private enum DeletionTime: Int {
        case tenSeconds = 10
        case thirtySeconds = 30
        case oneMinute = 60
        case oneAndHalfMinutes = 90
        
        var title: String {
            switch self {
            case .tenSeconds: return "10 seconds"
            case .thirtySeconds: return "30 seconds"
            case .oneMinute: return "1 minute"
            case .oneAndHalfMinutes: return "1.5 minutes"
            }
        }
        
        var identifier: String {
            switch self {
            case .tenSeconds: return "delete10"
            case .thirtySeconds: return "delete30"
            case .oneMinute: return "delete60"
            case .oneAndHalfMinutes: return "delete90"
            }
        }
    }
    
    // Flag to ensure we only register notification categories once
    private static var hasRegisteredNotificationCategories = false
    
    func directoryMonitor(_ monitor: DirectoryMonitor, didDetectNewImage path: String) {
        // Setup is only needed once - moved to a separate method
        setupNotificationCategories()
        
        // Create and post notification
        postNewImageNotification(for: path)
    }
    
    private func setupNotificationCategories() {
        // Only register category once per app launch
        guard !AppDelegate.hasRegisteredNotificationCategories else { return }
        
        // Create actions dynamically
        let deletionTimes: [DeletionTime] = [.tenSeconds, .thirtySeconds, .oneMinute, .oneAndHalfMinutes]
        let actions = deletionTimes.map { time in
            UNNotificationAction(identifier: time.identifier, title: time.title, options: [])
        }
        
        // Create category with actions
        let category = UNNotificationCategory(
            identifier: "imageDetected",
            actions: actions,
            intentIdentifiers: [],
            options: []
        )
        
        // Register category
        UNUserNotificationCenter.current().setNotificationCategories([category])
        AppDelegate.hasRegisteredNotificationCategories = true
    }
    
    private func postNewImageNotification(for path: String) {
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "New Screenshot Detected"
        content.body = "Would you like to delete '\(URL(fileURLWithPath: path).lastPathComponent)'?"
        content.sound = .default
        content.userInfo = ["filePath": path]
        content.categoryIdentifier = "imageDetected"
        
        // Create and add notification request
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error posting notification: \(error)")
            }
        }
    }
}
