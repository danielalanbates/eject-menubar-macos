import Cocoa

final class App: NSObject, NSApplicationDelegate {
    var item: NSStatusItem!
    let menu = NSMenu()

    func applicationDidFinishLaunching(_ n: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let b = item.button {
            b.image = NSImage(systemSymbolName: "eject.fill", accessibilityDescription: "Eject All")
            b.toolTip = "Click: eject all external drives. Right-click: menu"
            b.target = self
            b.action = #selector(clicked)
            b.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        let eject = NSMenuItem(title: "Eject All Drives", action: #selector(ejectAll), keyEquivalent: "e")
        eject.target = self
        menu.addItem(eject)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Eject All", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    // Left click = eject immediately (one click). Right click = menu.
    @objc func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            ejectAll()
        }
    }

    @discardableResult
    func run(_ args: [String]) -> (Int32, String) {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil"); p.arguments = args
        let out = Pipe(); p.standardOutput = out; p.standardError = out
        try? p.run(); p.waitUntilExit()
        return (p.terminationStatus, String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "")
    }

    // Whole physical disk (e.g. "disk4") backing a mounted volume path.
    func physicalDisk(for path: String) -> String? {
        let (_, info) = run(["info", "-plist", path])
        guard let d = try? PropertyListSerialization.propertyList(from: Data(info.utf8), format: nil) as? [String: Any] else { return nil }
        // For APFS volumes the container's physical store is what must be ejected.
        if let stores = d["APFSPhysicalStores"] as? [[String: Any]], let dev = stores.first?["DeviceIdentifier"] as? String {
            return dev.replacingOccurrences(of: #"s\d+$"#, with: "", options: .regularExpression)
        }
        if let parent = d["ParentWholeDisk"] as? String { return parent }
        return nil
    }

    @objc func ejectAll() {
        item.button?.isEnabled = false
        let keys: [URLResourceKey] = [.volumeIsInternalKey, .volumeIsRootFileSystemKey, .volumeLocalizedNameKey]
        let vols = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) ?? []
        var disks: [String: [String]] = [:]   // disk -> volume names
        for url in vols {
            guard let v = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if v.volumeIsRootFileSystem == true || v.volumeIsInternal == true { continue }
            guard url.path.hasPrefix("/Volumes/"), let disk = physicalDisk(for: url.path) else { continue }
            disks[disk, default: []].append(v.volumeLocalizedName ?? url.lastPathComponent)
        }
        DispatchQueue.global().async {
            var failed: [String] = []
            var count = 0
            for (disk, names) in disks {
                // Polite unmount first; if something (e.g. a sandbox VM with read-only handles) dissents, force it.
                var (rc, _) = self.run(["unmountDisk", disk])
                if rc != 0 { (rc, _) = self.run(["unmountDisk", "force", disk]) }
                if rc == 0 { (rc, _) = self.run(["eject", disk]) }
                if rc == 0 { count += names.count } else { failed.append(contentsOf: names) }
            }
            DispatchQueue.main.async {
                self.item.button?.isEnabled = true
                let note = NSUserNotification()
                note.title = failed.isEmpty ? "Ejected \(count) drive\(count == 1 ? "" : "s")" : "Could not eject: \(failed.joined(separator: ", "))"
                NSUserNotificationCenter.default.deliver(note)
                if !failed.isEmpty {
                    let a = NSAlert(); a.messageText = "Some drives are still in use"; a.informativeText = failed.joined(separator: "\n"); a.runModal()
                }
            }
        }
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let d = App()
app.delegate = d
app.run()
