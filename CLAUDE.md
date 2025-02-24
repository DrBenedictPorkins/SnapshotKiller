# Build Commands
- Build app: `./build.sh`
- Run via Xcode: Open `ImageMonitor.xcodeproj` and press ⌘R
- Run from terminal: `cd build && open ImageMonitor.app`

# Code Style Guidelines
- **Formatting**: 4-space indentation, PascalCase for types, camelCase for variables
- **Imports**: Foundation first, then other frameworks (Cocoa, UserNotifications)
- **Memory**: Use weak references for delegates and in closures to prevent retain cycles
- **Error Handling**: Use do-catch with specific error handling and fallback mechanisms
- **Types**: Strong typing throughout, careful optional handling with if-let and guard
- **Documentation**: Add comments for complex operations
- **Structure**: Follow protocol-oriented design, use delegates for communication
- **Threading**: Use DispatchQueue.main.async for UI updates
- **Constants**: Use camelCase with descriptive suffixes for UserDefaults keys

# Development Notes
- The app monitors a folder (default: Desktop) for new image files
- When a new image is detected, notification options are shown to delete after preset times
- App runs as menu bar application (LSUIElement=true in Info.plist)