import SwiftUI
import IOKit
import IOKit.hid
import Dispatch

let kU: CGFloat = 72
let kGap: CGFloat = 4
let kPad: CGFloat = 30

struct KeyPos: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let w: CGFloat
    let h: CGFloat
    let isEncoder: Bool
}

let positions: [KeyPos] = {
    let base: [(CGFloat, CGFloat, CGFloat, CGFloat, Bool)] = [
        (0, 0.5, 1, 1, false),
        (1, 0.375, 1, 1, false),
        (2, 0.125, 1, 1, false),
        (3, 0, 1, 1, false),
        (4, 0.125, 1, 1, false),
        (5, 0.25, 1, 1, false),
        (10.5, 0.25, 1, 1, false),
        (11.5, 0.125, 1, 1, false),
        (12.5, 0, 1, 1, false),
        (13.5, 0.125, 1, 1, false),
        (14.5, 0.375, 1, 1, false),
        (15.5, 0.5, 1, 1, false),
        (0, 1.5, 1, 1, false),
        (1, 1.375, 1, 1, false),
        (2, 1.125, 1, 1, false),
        (3, 1, 1, 1, false),
        (4, 1.125, 1, 1, false),
        (5, 1.25, 1, 1, false),
        (10.5, 1.25, 1, 1, false),
        (11.5, 1.125, 1, 1, false),
        (12.5, 1, 1, 1, false),
        (13.5, 1.125, 1, 1, false),
        (14.5, 1.375, 1, 1, false),
        (15.5, 1.5, 1, 1, false),
        (0, 2.5, 1, 1, false),
        (1, 2.375, 1, 1, false),
        (2, 2.125, 1, 1, false),
        (3, 2, 1, 1, false),
        (4, 2.125, 1, 1, false),
        (5, 2.25, 1, 1, false),
        (10.5, 2.25, 1, 1, false),
        (11.5, 2.125, 1, 1, false),
        (12.5, 2, 1, 1, false),
        (13.5, 2.125, 1, 1, false),
        (14.5, 2.375, 1, 1, false),
        (15.5, 2.5, 1, 1, false),
        (0, 3.5, 1, 1, false),
        (1, 3.375, 1, 1, false),
        (2, 3.125, 1, 1, false),
        (3, 3, 1, 1, false),
        (4, 3.125, 1, 1, false),
        (5, 3.25, 1, 1, false),
        (6, 2.75, 1.5, 1.5, true),
        (9.5, 2.75, 1.5, 1.5, true),
        (10.5, 3.25, 1, 1, false),
        (11.5, 3.125, 1, 1, false),
        (12.5, 3, 1, 1, false),
        (13.5, 3.125, 1, 1, false),
        (14.5, 3.375, 1, 1, false),
        (15.5, 3.5, 1, 1, false),
        (1.5, 4.375, 1, 1, false),
        (2.5, 4.125, 1, 1, false),
        (3.5, 4.15, 1, 1, false),
        (4.5, 4.25, 1, 1, false),
        (6, 4.25, 1, 1.5, false),
        (9.5, 4.25, 1, 1.5, false),
        (11, 4.25, 1, 1, false),
        (12, 4.15, 1, 1, false),
        (13, 4.125, 1, 1, false),
        (14, 4.375, 1, 1, false),
    ]
    return base.enumerated().map { KeyPos(id: $0.offset, x: $0.element.0, y: $0.element.1, w: $0.element.2, h: $0.element.3, isEncoder: $0.element.4) }
}()

struct Layer {
    let name: String
    let keys: [String]
}

func parseKeymap(_ url: URL) -> [Layer]? {
    guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
    var layerNames: [String] = []
    var layerBlocks: [[String]] = []

    let lines = content.components(separatedBy: "\n")
    var inEnum = false
    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("enum layer_names") || trimmed.hasPrefix("enum sofle_layers") {
            inEnum = true; continue
        }
        if inEnum {
            if trimmed.hasPrefix("};") { inEnum = false; continue }
            let cleaned = trimmed.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty && cleaned != "{" && !cleaned.hasPrefix("//") {
                layerNames.append(cleaned.replacingOccurrences(of: " =", with: ""))
            }
        }
    }

    var blockStarts: [Int] = []
    for (i, line) in lines.enumerated() {
        if line.contains("LAYOUT(") && line.contains("=") {
            blockStarts.append(i)
        }
    }

    for startLine in blockStarts {
        var blockContent = ""
        var depth = 0
        var started = false
        for lineNum in startLine..<lines.count {
            let line = lines[lineNum]
            for ch in line {
                if ch == "(" { depth += 1; started = true }
                if ch == ")" { depth -= 1 }
                if started && depth >= 1 {
                    if !(ch == "(" && depth == 1) { blockContent.append(ch) }
                }
                if started && depth == 0 { break }
            }
            if started && depth == 0 { break }
        }
        if blockContent.hasSuffix(")") { blockContent = String(blockContent.dropLast()) }

        let keys = blockContent
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "{" && $0 != "}" }

        layerBlocks.append(keys)
    }

    var layers: [Layer] = []
    for i in 0..<max(layerBlocks.count, layerNames.count) {
let name = i < layerNames.count ? layerNames[i] : "Layer \(i)"
            let keys = i < layerBlocks.count ? layerBlocks[i] : []
            let displayName = name.hasPrefix("_") ? String(name.dropFirst()) : name
            layers.append(Layer(name: displayName, keys: keys))
    }
    return layers.isEmpty ? nil : layers
}

func formatLabel(_ raw: String) -> String {
    let r = raw.trimmingCharacters(in: .whitespaces)
    if r.isEmpty { return "" }
    switch r {
    case "KC_TRNS": return "—"
    case "_______": return "—"
    case "KC_NO", "XXXXXXX": return ""
    case "KC_ESC": return "Esc"
    case "KC_ENT": return "↵"
    case "KC_BSPC": return "⌫"
    case "KC_SPC": return "Space"
    case "KC_TAB": return "Tab"
    case "KC_DEL": return "Del"
    case "KC_LSFT", "KC_RSFT": return "⇧"
    case "KC_LCTL", "KC_RCTL": return "Ctl"
    case "KC_LALT", "KC_RALT": return "Alt"
    case "KC_LOPT", "KC_ROPT": return "Opt"
    case "KC_LGUI", "KC_RGUI": return "⌘"
    case "KC_LCMD", "KC_RCMD": return "⌘"
    case "KC_MPLY": return "▶❚❚"
    case "KC_MUTE": return "🔇"
    case "KC_MPRV": return "⏮"
    case "KC_MNXT": return "⏭"
    case "KC_VOLD": return "▿"
    case "KC_VOLU": return "▵"
    case "KC_BR_INC": return "☀+"
    case "KC_BR_DEC": return "☀−"
    case "KC_CAPS": return "Caps"
    case "KC_PGUP": return "Pg↑"
    case "KC_PGDN": return "Pg↓"
    case "KC_HOME": return "Home"
    case "KC_END": return "End"
    case "KC_INS": return "Ins"
    case "KC_PSCR": return "PrtSc"
    case "KC_APP": return "App"
    case "KC_GRV": return "`"
    case "KC_BSLS": return "\\"
    case "KC_SLSH": return "/"
    case "KC_SCLN": return ";"
    case "KC_QUOT": return "'"
    case "KC_LBRC": return "["
    case "KC_RBRC": return "]"
    case "KC_MINS": return "-"
    case "KC_EQL": return "="
    case "KC_COMM": return ","
    case "KC_DOT": return "."
    case "KC_MS_UP": return "Mouse↑"
    case "KC_MS_DOWN": return "Mouse↓"
    case "KC_MS_LEFT": return "Mouse←"
    case "KC_MS_RIGHT": return "Mouse→"
    case "KC_MS_BTN1": return "⊕1"
    case "KC_MS_BTN2": return "⊕2"
    case "KC_MS_WHLU": return "Scroll↑"
    case "KC_MS_WHLD": return "Scroll↓"
    case "KC_UNDO": return "Undo"
    case "KC_CUT": return "Cut"
    case "KC_COPY": return "Copy"
    case "KC_PASTE": return "Paste"
    case "KC_LOCK": return "🔒"
    case "RM_NEXT": return "FX→"
    case "RM_PREV": return "FX←"
    case "RM_HUEU": return "H↑"
    case "RM_HUED": return "H↓"
    case "RM_SATU": return "S↑"
    case "RM_SATD": return "S↓"
    case "RM_VALU": return "V↑"
    case "RM_VALD": return "V↓"
    case "RM_SPDU": return "Sp↑"
    case "RM_SPDD": return "Sp↓"
    case "RM_TOGG": return "Toggle"
    case "KC_LED_MODE": return "LED⏻"
    case "KC_VIZ_TOGGLE": return "VIZ⏻"
    default:
        if r.hasPrefix("MO(") { return r }
        if r.hasPrefix("S(") {
            let inner = String(r.dropFirst(2).dropLast())
            if let shift = shiftedChar(inner) { return shift }
            return "⇧\(formatLabel(inner))"
        }
        if r.hasPrefix("C(") {
            let inner = String(r.dropFirst(2).dropLast())
            return "Ctl+\(formatLabel(inner))"
        }
        if r.hasPrefix("KC_") {
            let name = String(r.dropFirst(3))
            if name.count == 1 { return name }
            if let n = Int(name), name == String(n) { return name }
            if name.hasPrefix("F") && name.dropFirst().allSatisfy(\.isNumber) { return name }
            if name == "KEY_BRI_UP" { return "☀+K" }
            if name == "KEY_BRI_DN" { return "☀−K" }
            if name == "UGL_BRI_UP" { return "☀+U" }
            if name == "UGL_BRI_DN" { return "☀−U" }
            return name
        }
        return r
    }
}

private func shiftedChar(_ kc: String) -> String? {
    let map: [String: String] = [
        "KC_1": "!", "KC_2": "@", "KC_3": "#", "KC_4": "$", "KC_5": "%",
        "KC_6": "^", "KC_7": "&", "KC_8": "*", "KC_9": "(", "KC_0": ")",
        "KC_MINS": "_", "KC_EQL": "+", "KC_BSLS": "|",
        "KC_LBRC": "{", "KC_RBRC": "}",
        "KC_SCLN": ":", "KC_QUOT": "\"",
        "KC_COMM": "<", "KC_DOT": ">", "KC_SLSH": "?", "KC_GRV": "~",
    ]
    return map[kc]
}

struct KeyView: View {
    let label: String
    let isEncoder: Bool
    let isTransparent: Bool

    var body: some View {
        Group {
            if isEncoder {
                ZStack {
                    Circle().fill(Color.gray.opacity(0.35))
                    Circle().stroke(Color.white.opacity(0.6), lineWidth: 1)
                    Text(label).font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.5)
                }
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 6).fill(isTransparent ? Color.gray.opacity(0.15) : Color.gray.opacity(0.35))
                    RoundedRectangle(cornerRadius: 6).stroke(isTransparent ? Color.white.opacity(0.2) : Color.white.opacity(0.6), lineWidth: 1)
                    Text(label).font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(isTransparent ? Color.white.opacity(0.35) : .white).lineLimit(1).minimumScaleFactor(0.4)
                }
            }
        }
    }
}

struct KeyboardView: View {
    let layer: Layer
    let layerIndex: Int
    let totalLayers: Int
    let layerNames: [String]
    let keyboardConnected: Bool
    let onLayerChange: (Int) -> Void

    var body: some View {
        let maxX = positions.map { $0.x + $0.w }.max()! + 0.5
        let maxY = positions.map { $0.y + $0.h }.max()! + 0.5
        let totalW = maxX * kU + kPad * 2

        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button(action: { NSApp.keyWindow?.orderOut(nil) }) {
                    Text("✕")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                }
                .buttonStyle(.plain)
                Text("Sofle Choc").font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
                if keyboardConnected {
                    Text("⌨")
                        .font(.system(size: 14))
                        .foregroundColor(.green.opacity(0.8))
                }
                Spacer()
                ForEach(0..<totalLayers, id: \.self) { i in
                    Button(action: { onLayerChange(i) }) {
                        Text(layerNames.count > i ? layerNames[i] : "L\(i)")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(i == layerIndex ? .black : .white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(i == layerIndex ? Color.orange : Color.white.opacity(0.25))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, kPad)
            .padding(.top, 8)
            .padding(.bottom, 6)

            ZStack {
                ForEach(positions) { pos in
                    let idx = pos.id
                    let raw = idx < layer.keys.count ? layer.keys[idx] : ""
                    let label = formatLabel(raw)
                    KeyView(label: label, isEncoder: pos.isEncoder, isTransparent: raw == "KC_TRNS" || raw == "_______")
                        .frame(width: pos.w * kU - kGap, height: pos.h * kU - kGap)
                        .position(x: pos.x * kU + kPad + kU / 2, y: pos.y * kU + kPad + kU / 2)
                }
            }
            .frame(width: totalW, height: maxY * kU + kPad * 2)
        }
        .background(Color.black)
    }
}

class SofleHIDMonitor: ObservableObject {
    @Published var detectedLayer: Int = -1
    @Published var connected: Bool = false
    @Published var toggleRequested: Bool = false
    private var manager: IOHIDManager?
    private var timer: Timer?

    func start() {
        let mgr = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        self.manager = mgr

        let matching: [String: Any] = [
            kIOHIDVendorIDKey: 0x424C,
            kIOHIDProductIDKey: 0x5343,
            kIOHIDPrimaryUsagePageKey: 0xFF60,
            kIOHIDPrimaryUsageKey: 0x61
        ]
        IOHIDManagerSetDeviceMatching(mgr, matching as CFDictionary)
        IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetMain(), CFRunLoopMode.defaultMode!.rawValue)

        let openResult = IOHIDManagerOpen(mgr, 0)
        if openResult != kIOReturnSuccess {
            return
        }

        IOHIDManagerRegisterInputReportCallback(mgr, { context, _, _, type, reportID, report, reportLen in
            guard let ctx = context else { return }
            let monitor = Unmanaged<SofleHIDMonitor>.fromOpaque(ctx).takeUnretainedValue()
            if reportLen >= 2 && report[0] == 0x80 {
                let layer = Int(report[1])
                DispatchQueue.main.async {
                    monitor.detectedLayer = layer
                    monitor.connected = true
                }
            } else if reportLen >= 1 && report[0] == 0x81 {
                DispatchQueue.main.async {
                    monitor.toggleRequested = true
                }
            }
        }, Unmanaged.passUnretained(self).toOpaque())

        startPolling()
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.queryLayer()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func queryLayer() {
        guard let mgr = manager else { return }
        let devices = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> ?? []
        for device in devices {
            var report = [UInt8](repeating: 0 as UInt8, count: 32)
            report[0] = 0x80
            _ = IOHIDDeviceSetReport(device, kIOHIDReportTypeOutput, 0, report, 32)
            // Also try input report - the keyboard may send asynchronously
            // via layer_state_set_user, so we mainly rely on the callback
        }
    }

    deinit {
        timer?.invalidate()
        if let mgr = manager {
            IOHIDManagerClose(mgr, 0)
        }
    }
}

struct ContentView: View {
    @State private var layers: [Layer] = []
    @State private var currentLayer: Int = 0
    @State private var errorMsg: String? = nil
    @ObservedObject var hidMonitor = SofleHIDMonitor()
    @State private var keymapPath: String = ""
    @State private var watcher: DispatchSourceFileSystemObject?
    @State private var reloadTimer: Timer?

    mutating func selectLayer(_ i: Int) {
        if i >= 0 && i < layers.count {
            currentLayer = i
        }
    }

    var body: some View {
        Group {
            if let err = errorMsg {
                VStack(spacing: 8) {
                    Text("Error").font(.headline).foregroundColor(.red)
                    Text(err).font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                }.padding()
            } else if layers.isEmpty {
                Text("No keymap loaded").foregroundColor(.secondary).padding()
            } else {
                KeyboardView(
                    layer: layers[currentLayer],
                    layerIndex: currentLayer,
                    totalLayers: layers.count,
                    layerNames: layers.map(\.name),
                    keyboardConnected: hidMonitor.connected
                ) { i in currentLayer = i }
            }
        }
        .frame(minWidth: 1280, minHeight: 480)
        .onAppear { loadKeymap(); hidMonitor.start() }
        .onChange(of: hidMonitor.detectedLayer) { newLayer in
            if newLayer >= 0 && newLayer < layers.count && newLayer != currentLayer {
                currentLayer = newLayer
            }
        }
    }

    func loadKeymap() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let defaultPath = "\(home)/projects/qmk_firmware/keyboards/sofle_choc/keymaps/jcanton/keymap.c"
        keymapPath = defaultPath
        reloadFromFile()
        startFileWatcher()
    }

    func reloadFromFile() {
        let url = URL(fileURLWithPath: keymapPath)
        if let parsed = parseKeymap(url) {
            layers = parsed
            if currentLayer >= layers.count { currentLayer = 0 }
            errorMsg = nil
        } else {
            errorMsg = "Failed to parse keymap at:\n\(keymapPath)"
        }
    }

    func startFileWatcher() {
        let url = URL(fileURLWithPath: keymapPath)
        watcher = DispatchSource.makeFileSystemObjectSource(fileDescriptor: open(url.path, O_EVTONLY), eventMask: .write, queue: .main)
        watcher?.setEventHandler {
            self.debounceReload()
        }
        watcher?.resume()
    }

    func debounceReload() {
        reloadTimer?.invalidate()
        reloadTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.reloadFromFile()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var contentView: ContentView!
    var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        contentView = ContentView()
        let hosting = NSHostingView(rootView: contentView)
        let builtinScreen = NSScreen.screens.first { $0.deviceDescription[NSDeviceDescriptionKey("Builtin")] as? Bool == true }
        let targetScreen = builtinScreen ?? NSScreen.main!
        let screenBounds = targetScreen.visibleFrame
        let winW: CGFloat = 1300
        let winH: CGFloat = 560
        let winX = screenBounds.origin.x + 100
        let winY = screenBounds.origin.y + screenBounds.height - winH - 20

        window = NSWindow(
            contentRect: NSRect(x: winX, y: winY, width: winW, height: winH),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isMovableByWindowBackground = true
        window.title = "KeebViz"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeebViz")
            button.image?.size = NSSize(width: 18, height: 18)
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show Window", action: #selector(showWindow), keyEquivalent: "s")
        menu.addItem(withTitle: "Hide Window", action: #selector(hideWindow), keyEquivalent: "h")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Reload Keymap", action: #selector(reloadKeymap), keyEquivalent: "r")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit KeebViz", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if let ch = event.characters {
                switch ch {
                case "1": self.contentView.selectLayer(0)
                case "2": self.contentView.selectLayer(1)
                case "3": self.contentView.selectLayer(2)
                case "4": self.contentView.selectLayer(3)
                default: break
                }
            }
            return event
        }

        // Monitor HID toggle requests
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.contentView.hidMonitor.toggleRequested {
                self.contentView.hidMonitor.toggleRequested = false
                if self.window.isVisible {
                    self.window.orderOut(nil)
                } else {
                    self.window.makeKeyAndOrderFront(nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
        }
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func hideWindow() {
        window.orderOut(nil)
    }

    @objc func reloadKeymap() {
        contentView.reloadFromFile()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
enum KeebVizMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
