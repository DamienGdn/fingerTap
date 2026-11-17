import AppKit
import FingerTapCore
import SwiftUI

let settingsWindowID = "settings"

@main
struct FingerTapApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(model)
        } label: {
            Image(systemName: model.isEnabled ? "hand.tap.fill" : "hand.tap")
        }
        .menuBarExtraStyle(.window)

        Window("FingerTap", id: settingsWindowID) {
            SettingsView().environmentObject(model)
        }
        .windowResizability(.contentSize)
    }
}

// MARK: - Shared pieces

/// Brand gradient, also used by the app icon (scripts/make-art.swift).
extension LinearGradient {
    static let brand = LinearGradient(colors: [Color(red: 0.38, green: 0.36, blue: 0.98), Color(red: 0.85, green: 0.32, blue: 0.78)],
                                      startPoint: .topLeading, endPoint: .bottomTrailing)
}

/// SF Symbol on a rounded gradient square, like a small app icon.
struct Badge: View {
    let symbol: String
    var size: CGFloat = 28
    var style: AnyShapeStyle = AnyShapeStyle(LinearGradient.brand)

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(style)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.5, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }
}

/// Tinted rounded box holding a warning or a hint.
struct Callout<Content: View>: View {
    var tint: Color = .orange
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 6) { content }
            Spacer(minLength: 0)
        }
        .font(.callout)
        .padding(10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

// MARK: - Menu bar

struct MenuView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Badge(symbol: "hand.tap.fill", size: 32, style: model.isEnabled ? AnyShapeStyle(LinearGradient.brand)
                                                                               : AnyShapeStyle(Color.gray))
                VStack(alignment: .leading, spacing: 1) {
                    Text("FingerTap").font(.headline)
                    Text(model.isEnabled ? "Active" : "Paused").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Enabled", isOn: $model.isEnabled.animation()).toggleStyle(.switch).labelsHidden()
            }

            if model.trackpadCount < 0 {
                Callout(symbol: "exclamationmark.triangle.fill") { Text("Trackpad access is unavailable on this Mac.") }
            } else if model.trackpadCount == 0 {
                Callout(symbol: "exclamationmark.triangle.fill") { Text("No trackpad found.") }
            }

            if !model.isTrusted {
                Callout(symbol: "lock.fill") {
                    Text("Allow Accessibility so taps can send shortcuts.")
                    Button("Grant Access…") { model.requestAccessibility() }.controlSize(.small)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Last gesture").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
                Text(model.lastEvent ?? String(localized: "Double tap or swipe with 3, 4 or 5 fingers."))
                    .font(.callout).lineLimit(2)
                    .contentTransition(.opacity)
                    .animation(.default, value: model.lastEvent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Divider()
            Toggle("Launch at login", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
            HStack {
                Button {
                    openWindow(id: settingsWindowID)
                    NSApp.activate()
                } label: { Label("Settings…", systemImage: "gearshape") }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }
}

// MARK: - Settings window

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selection: String?
    @State private var fingers = 3

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(model.configuration.rules) { rule in
                    HStack(spacing: 10) {
                        AppIcon(bundleID: rule.bundleID).frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(rule.name)
                            Text(shortcutCount(rule.bindings.count)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 2)
                    .tag(rule.bundleID)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HStack(spacing: 2) {
                    Button { selection = model.chooseApp() ?? selection } label: {
                        Image(systemName: "plus").frame(width: 22, height: 22)
                    }
                    .help("Add an App")
                    Button {
                        if let selection { model.configuration.removeApp(bundleID: selection) }
                        selection = model.configuration.rules.first?.bundleID
                    } label: { Image(systemName: "minus").frame(width: 22, height: 22) }
                        .disabled(selection == nil)
                        .help("Remove the App")
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(8)
                .background(.bar)
            }
            .navigationSplitViewColumnWidth(220)
        } detail: {
            detail
        }
        .frame(width: 760, height: 520)
        .onAppear { selection = selection ?? model.configuration.rules.first?.bundleID }
    }

    private func shortcutCount(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No shortcut")
        case 1: String(localized: "1 shortcut")
        default: String(localized: "\(count) shortcuts")
        }
    }

    @ViewBuilder private var detail: some View {
        if let bundleID = selection, let rule = model.configuration.rules.first(where: { $0.bundleID == bundleID }) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 14) {
                        AppIcon(bundleID: bundleID).frame(width: 52, height: 52)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(rule.name).font(.title2.bold())
                            Text(bundleID).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                    }

                    HStack {
                        Text("When this app is in front:").font(.headline)
                        Spacer()
                        Picker("Fingers", selection: $fingers.animation(.snappy)) {
                            ForEach(Array(GestureDetector.fingerRange), id: \.self) { Text("\($0) fingers").tag($0) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(FingerTapCore.Gesture.allCases.enumerated()), id: \.element) { index, gesture in
                            if index > 0 { Divider().padding(.leading, 52) }
                            GestureRow(gesture: gesture, fingers: fingers, shortcut: Binding(
                                get: { rule.shortcut(gesture, fingers: fingers) },
                                set: { model.configuration.setShortcut($0, for: gesture, fingers: fingers, bundleID: bundleID) }))
                        }
                    }
                    .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.separator))
                }
                .padding(24)
            }
        } else {
            ContentUnavailableView {
                Label("No App Selected", systemImage: "hand.tap")
            } description: {
                Text("Add an app with +, then record a shortcut for each gesture.")
            }
        }
    }
}

struct GestureRow: View {
    let gesture: FingerTapCore.Gesture
    let fingers: Int
    @Binding var shortcut: KeyShortcut?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Badge(symbol: gesture.symbol, size: 28,
                      style: shortcut == nil ? AnyShapeStyle(Color.secondary.opacity(0.5)) : AnyShapeStyle(LinearGradient.brand))
                Text(gesture.label)
                Spacer()
                ShortcutRecorder(shortcut: $shortcut)
            }
            if let conflict = SystemGestures.conflict(gesture, fingers: fingers) {
                Label(conflict, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange).padding(.leading, 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

struct AppIcon: View {
    let bundleID: String

    var body: some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
        } else {
            Image(systemName: "app.dashed").resizable().foregroundStyle(.secondary)
        }
    }
}

/// Button that records the next key combination typed. Escape cancels.
struct ShortcutRecorder: View {
    @Binding var shortcut: KeyShortcut?
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                isRecording ? stopRecording() : startRecording()
            } label: {
                Group {
                    if isRecording {
                        Text("Type a shortcut…").foregroundStyle(Color.accentColor)
                    } else if let shortcut {
                        Text(shortcut.display).font(.system(.body, design: .rounded).weight(.semibold))
                    } else {
                        Text("Record Shortcut").foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 140)
                .padding(.vertical, 5)
                .padding(.horizontal, 10)
                .background(.background, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isRecording ? Color.accentColor : Color.secondary.opacity(0.35), lineWidth: isRecording ? 2 : 1))
                .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button { shortcut = nil } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Remove the Shortcut")
                .opacity(shortcut != nil && !isRecording ? 1 : 0)
                .disabled(shortcut == nil || isRecording)
        }
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode != 53, let recorded = KeyShortcut(event: event) {
                shortcut = recorded
            }
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
