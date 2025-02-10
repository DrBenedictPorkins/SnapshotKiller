import Foundation

protocol DirectoryMonitorDelegate: AnyObject {
    func directoryMonitor(_ monitor: DirectoryMonitor, didDetectNewImage path: String)
}
