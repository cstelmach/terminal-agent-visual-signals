import SwiftUI

struct OpenSessionsButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("Open Sessions") {
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async { openWindow(id: "sessions") }
        }
    }
}

struct SessionsView: View {
    @ObservedObject var model: SessionsModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Sessions").font(.title2.bold())
                Spacer()
                Menu("Set Priority") {
                    ForEach(SurfacePriority.allCases) { priority in
                        Button(priority.rawValue) { model.setPriority(priority, for: model.selection) }
                    }
                }
                .disabled(model.selection.isEmpty || !model.catalogueAvailable || model.priorityStorageError != nil)
                Button("Clear Selection") { model.selection.removeAll() }
                    .disabled(model.selection.isEmpty)
                Button("Refresh") { model.refresh() }.disabled(model.refreshing)
            }
            Text(model.status).font(.callout).foregroundColor(model.catalogueAvailable ? .secondary : .primary)
            Text(model.visualRestrictionsStatus.message).font(.callout)
                .foregroundColor(model.visualRestrictionsStatus.disablesRestrictions ? .primary : .secondary)
            if let error = model.priorityStorageError { Text(error).foregroundColor(.red) }
            Table(model.rows, selection: $model.selection) {
                TableColumn("Terminal") { row in
                    VStack(alignment: .leading) {
                        Text(row.title ?? "Title unavailable").lineLimit(1)
                        Text(row.tty ?? row.id.terminalID).font(.system(.caption, design: .monospaced))
                        if row.mappingIssue != nil { Text("Mapping unavailable").font(.caption) }
                        if row.tabSelected == false { Text("Hidden tab").font(.caption).foregroundColor(.secondary) }
                    }
                    .help("Window \(row.windowID), tab \(row.tabID), terminal \(row.id.terminalID)")
                    .accessibilityLabel("\(row.title ?? "Terminal"), \(row.tty ?? row.id.terminalID)")
                }
                .width(min: 220, ideal: 280)
                TableColumn("Directory") { row in
                    Text(row.directory ?? "Directory unavailable").lineLimit(2).help(row.directory ?? "Unavailable")
                }
                .width(min: 160, ideal: 250)
                TableColumn("Priority") { row in
                    Picker("Priority", selection: Binding(
                        get: { model.priority(for: row.id) },
                        set: { model.setPriority($0, for: [row.id]) }
                    )) {
                        ForEach(SurfacePriority.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .accessibilityLabel("Priority for \(row.tty ?? row.id.terminalID)")
                    .disabled(!model.catalogueAvailable || model.priorityStorageError != nil)
                }
                .width(100)
                TableColumn("Observations") { row in
                    let coverage = model.visualCoverage[row.id]
                    VStack(alignment: .leading) {
                        if let observation = coverage?.observation {
                            let provider = observation.provider.capitalized
                            let state = observation.state == "complete" ? "Response ended"
                                : observation.state.replacingOccurrences(of: "_", with: " ").capitalized
                            Text("\(observation.verifiedAgent ? provider : "Unverified \(provider)") · \(state)")
                                .lineLimit(2)
                            Text("Observed \(Date(timeIntervalSince1970: observation.observedAt), style: .relative) ago")
                                .font(.caption).foregroundColor(.secondary)
                            if observation.provider == "codex" {
                                Text("Completion-only coverage").font(.caption).foregroundColor(.secondary)
                            }
                        } else {
                            Text("No agent observation")
                            Text("Not observed").font(.caption).foregroundColor(.secondary)
                        }
                        Text(coverage?.status ?? "Observation coverage unavailable.")
                            .font(.caption).foregroundColor(.secondary).lineLimit(2)
                    }
                }
                .width(min: 160, ideal: 180)
                TableColumn("Navigate") { row in
                    Button("Go To") { model.goTo(row.id) }
                        .accessibilityLabel("Go To \(row.tty ?? row.id.terminalID)")
                        .disabled(!model.catalogueAvailable || row.mappingIssue != nil || model.navigating != nil)
                }
                .width(80)
            }
            HStack {
                Text("\(model.selection.count) selected")
                Spacer()
                Text("Focus: Off")
                if let date = model.refreshedAt { Text("Catalogue refreshed \(date, style: .relative) ago") }
            }
            .font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        .frame(minWidth: 850, minHeight: 350)
        .onAppear { model.opened() }
        .onDisappear { model.closed() }
    }
}
