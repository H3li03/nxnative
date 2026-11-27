import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileSlot: View {
    let title: String
    let hint: String
    let folder: Bool
    @Binding var path: String
    @State private var hovering = false
    var body: some View {
        HStack {
            Image(systemName: folder ? "folder" : "doc").font(.title2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(path.isEmpty ? hint : path).font(.caption)
                    .foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Button("Choose…") {
                let p = NSOpenPanel()
                p.canChooseDirectories = folder
                p.canChooseFiles = !folder
                p.allowsMultipleSelection = false
                if p.runModal() == .OK, let u = p.url { path = u.path }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 8).fill(hovering ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
        .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
            guard let p = providers.first else { return false }
            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let url = (item as? URL) ?? (item as? Data).flatMap { URL(dataRepresentation: $0, relativeTo: nil) }
                guard let url = url, url.isFileURL else { return }
                DispatchQueue.main.async {
                    var dir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &dir), dir.boolValue == folder { path = url.path }
                }
            }
            return true
        }
    }
}

final class Builder: ObservableObject {
    @Published var output = ""
    @Published var running = false
    @Published var status = "Ready"
    private var process: Process?
    func start(repo: String, work: String, target: String, keys: String, base: String, update: String, dlc: String, reuse: Bool, pcTextures: String) {
        guard !running else { return }
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/share/dotnet:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        env["PYTHONUNBUFFERED"] = "1"
        env["MGS4_PC_TEXTURES"] = pcTextures
        for (k,v) in ["MGS4_GUI":"1","MGS4_WORK":work,"MGS4_TARGET":target,"MGS4_KEYS":keys,"MGS4_BASE":base,"MGS4_UPDATE":update,"MGS4_DLC":dlc,"MGS4_REUSE":reuse ? "y" : "n"] { env[k] = v }
        run(arguments: [repo + "/build_mgs4.sh"], directory: repo, env: env, activity: "Building", success: "Build complete")
    }

    func prepare(work: String, repo: String, completion: @escaping (Bool) -> Void) {
        guard !running else { return }
        var env = ProcessInfo.processInfo.environment
        env["GIT_TERMINAL_PROMPT"] = "0"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (env["PATH"] ?? "")
        let script = #"""
set -euo pipefail
repo="$1"
url="https://github.com/H3li03/nxnative.git"
branch="mgs4-builder-v1.2-dev"
if [ -e "$repo" ] || [ -L "$repo" ]; then
    [ -d "$repo/.git" ] || { echo "Existing folder is not a Git checkout: $repo"; exit 1; }
    origin=$(git -C "$repo" remote get-url origin)
    case "$origin" in "$url"|https://github.com/H3li03/nxnative|git@github.com:H3li03/nxnative.git) ;; *) echo "Unexpected origin: $origin"; exit 1;; esac
    [ "$(git -C "$repo" branch --show-current)" = "$branch" ] || { echo "Wrong branch; select another project folder."; exit 1; }
    [ -z "$(git -C "$repo" status --porcelain --untracked-files=no)" ] || { echo "Local tracked changes detected; update manually."; exit 1; }
    git -C "$repo" pull --ff-only origin "$branch"
else
    git clone --progress --single-branch --branch "$branch" "$url" "$repo"
fi
git -C "$repo" submodule update --init --recursive --progress
git -C "$repo" log -1 --oneline
test -f "$repo/build_mgs4.sh"
"""#
        run(arguments: ["-c", script, "setup", repo], directory: work, env: env, activity: "Preparing project", success: "Project ready", completion: completion)
    }

    private func run(arguments: [String], directory: String, env: [String:String], activity: String, success: String, completion: ((Bool) -> Void)? = nil) {
        let p = Process()
        let pipe = Pipe()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = arguments
        p.currentDirectoryURL = URL(fileURLWithPath: directory)
        p.environment = env
        p.standardOutput = pipe
        p.standardError = pipe
        p.standardInput = FileHandle.nullDevice
        output = ""
        running = true
        status = activity + "…"
        process = p
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            let chunk = String(decoding: data, as: UTF8.self)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.output += chunk
                if self.output.count > 300000 { self.output = String(self.output.suffix(250000)) }
            }
        }
        p.terminationHandler = { [weak self] task in
            DispatchQueue.main.async {
                self?.running = false
                self?.status = task.terminationStatus == 0 ? success : "\(activity) failed (exit \(task.terminationStatus))"
                self?.process = nil
                completion?(task.terminationStatus == 0)
            }
        }
        do { try p.run() } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            running = false
            status = "Could not start"
            output = error.localizedDescription
            process = nil
            completion?(false)
        }
    }
}

struct Console: NSViewRepresentable {
    let text: String
    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        let view = scroll.documentView as! NSTextView
        view.isEditable = false
        view.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        view.textColor = .textColor
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let view = scroll.documentView as! NSTextView
        if view.string != text {
            view.string = text
            view.scrollToEndOfDocument(nil)
        }
    }
}

struct ContentView: View {
    @StateObject private var builder = Builder()
    @AppStorage("repo") private var repo = ProcessInfo.processInfo.environment["MGS4_REPO"] ?? ""
    @AppStorage("work") private var work = NSHomeDirectory() + "/MGS4-Native"
    @AppStorage("keys") private var keys = ""
    @AppStorage("base") private var base = ""
    @AppStorage("update") private var update = ""
    @AppStorage("dlc") private var dlc = ""
    @AppStorage("target") private var target = "2"
    @AppStorage("pcTextures") private var pcTextures = ""
    @State private var reuse = true
    @State private var confirm = false
    @State private var didPrompt = false
    @AppStorage("setupComplete") private var setupComplete = false

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.title = "Select MGS4 project folder"
        panel.prompt = "Select folder"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let root = url.path
            let existing = ["nxnative", "nxnative-ipados"].map { url.appendingPathComponent($0).path }.first { FileManager.default.fileExists(atPath: $0 + "/.git") }
            let destination = existing ?? url.appendingPathComponent("nxnative").path
            builder.prepare(work: root, repo: destination) { ok in
                if ok { work = root; repo = destination; setupComplete = true }
            }
        }
    }
    var valid: Bool {
        FileManager.default.fileExists(atPath: repo + "/build_mgs4.sh") &&
        !work.isEmpty && [keys,base,update,dlc].allSatisfy {
            var dir: ObjCBool = false
            return FileManager.default.fileExists(atPath: $0, isDirectory: &dir) && !dir.boolValue
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("MGS4 Native Builder 1.2 Dev").font(.largeTitle.bold())
            Text("Build native macOS and iPadOS applications from your own game files.").foregroundStyle(.secondary)
            HSplitView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("Select project folder & download sources…") { chooseProject() }
                        Button("Update repository") {
                            builder.prepare(work: work, repo: repo) { ok in if ok { setupComplete = true } }
                        }.disabled(repo.isEmpty || !FileManager.default.fileExists(atPath: repo + "/.git"))
                        FileSlot(title: "Repository", hint: "Set automatically by project setup", folder: true, path: $repo)
                        FileSlot(title: "Workspace", hint: "Project output folder", folder: true, path: $work)
                        FileSlot(title: "Production keys", hint: "Drop prod.keys", folder: false, path: $keys)
                        FileSlot(title: "Base game", hint: "Drop base NSP", folder: false, path: $base)
                        FileSlot(title: "Update v393216", hint: "Drop update NSP", folder: false, path: $update)
                        FileSlot(title: "Multilingual DLC", hint: "Drop multilingual NSP", folder: false, path: $dlc)
                        FileSlot(title: "PC textures (optional)", hint: "Select extracted MGS4 folder", folder: true, path: $pcTextures)
                        Button("Use Switch textures only") { pcTextures = "" }
                        Picker("Target", selection: $target) {
                            Text("macOS").tag("1")
                            Text("iOS / iPadOS").tag("2")
                            Text("Both").tag("3")
                        }.pickerStyle(.segmented)
                        Toggle("Reuse existing game and DLC dumps", isOn: $reuse)
                        Text("Existing applications are backed up. Existing dumps are protected.").font(.caption).foregroundStyle(.secondary)
                    }.padding(4).disabled(builder.running)
                }.frame(minWidth: 340, idealWidth: 390)
                VStack(alignment: .leading) {
                    HStack {
                        Text("Build console").font(.headline)
                        Spacer()
                        Button("Copy log") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(builder.output, forType: .string) }
                    }
                    Console(text: builder.output).border(Color.secondary.opacity(0.3))
                    HStack {
                        if builder.running { ProgressView().controlSize(.small) }
                        Text(builder.status)
                        Spacer()
                        Button("Open workspace") { NSWorkspace.shared.open(URL(fileURLWithPath: work)) }
                        Button("Build") { confirm = true }.keyboardShortcut(.defaultAction).disabled(!valid || builder.running)
                    }
                }.padding(4).frame(minWidth: 420)
            }
        }.padding(20).frame(minWidth: 850, minHeight: 640)
        .onAppear {
            if !didPrompt && (!setupComplete || !FileManager.default.fileExists(atPath: repo + "/build_mgs4.sh")) {
                didPrompt = true
                DispatchQueue.main.async { chooseProject() }
            }
        }
        .confirmationDialog("Start build? Existing outputs will be backed up.", isPresented: $confirm, titleVisibility: .visible) {
            Button("Start build") { builder.start(repo: repo, work: work, target: target, keys: keys, base: base, update: update, dlc: dlc, reuse: reuse, pcTextures: pcTextures) }
            Button("Cancel", role: .cancel) {}
        }
    }
}
@main struct MGS4BuilderApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
