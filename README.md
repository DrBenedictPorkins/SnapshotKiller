# ImageMonitor

ImageMonitor is a macOS menu bar application born out of a common screenshot management problem. While macOS offers various screenshot options (like ⇧⌃⌘4 for clipboard-only captures), some applications don't handle clipboard-pasted images well, forcing users to save screenshots as files (⇧⌘4). These files can quickly accumulate and clutter your desktop or screenshots folder.

ImageMonitor solves this problem by automatically detecting new screenshot files and offering timed deletion options, helping keep your directories clean and organized.

## Features

- 🖥️ Lives in the menu bar for easy access
- 📁 Monitors your Desktop (or any chosen folder) for new screenshots
- 🔔 Sends notifications when new screenshots are detected
- ⏱️ Offers flexible deletion timers:
    - 10 seconds
    - 30 seconds
    - 1 minute
    - 1.5 minutes
- 🎯 Allows custom folder monitoring
- 💾 Remembers your last monitored folder
- ⚙️ Configurable notification settings

## Usage

1. Launch ImageMonitor
2. The app will appear as a folder icon in your menu bar
3. By default, it monitors your Desktop folder
4. Click the menu bar icon to:
    - Choose a different folder to monitor
    - Toggle deletion notifications
    - Quit the application

When a new screenshot is detected, you'll receive a notification with options to:
- Delete the file after 10 seconds
- Delete the file after 30 seconds
- Delete the file after 1 minute
- Delete the file after 1.5 minutes

## Requirements

- macOS (built with Swift)
- Notification permissions (requested on first launch)

## Privacy

The application requires:
- Access to the folder you choose to monitor
- Permission to send notifications
- Permission to delete files in the monitored folder

## Installation

[Add installation instructions based on how you distribute the app]

## Support

[Add support information or contact details]

## License

[Add your license information]