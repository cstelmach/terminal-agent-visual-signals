import SwiftUI

struct PreferencesView: View {
    @AppStorage("tavs_prefs_tab") private var selectedTab = 0
    @ObservedObject var scheduler: Scheduler

    private let scheduleURL: URL
    private let userConfURL: URL

    init(scheduler: Scheduler) {
        self.scheduler = scheduler
        let home = FileManager.default.homeDirectoryForCurrentUser
        self.scheduleURL = home.appendingPathComponent(".tavs/schedule.json")
        self.userConfURL = home.appendingPathComponent(".tavs/user.conf")
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            ScheduleTab(scheduleURL: scheduleURL, scheduler: scheduler)
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(0)
            AppearanceTab(userConfURL: userConfURL)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
                .tag(1)
            IdentityTab(userConfURL: userConfURL)
                .tabItem { Label("Identity", systemImage: "person.crop.circle") }
                .tag(2)
        }
        .frame(minWidth: 520, minHeight: 420)
        .padding()
    }
}

// MARK: - Schedule Tab

private struct ScheduleTab: View {
    let scheduleURL: URL
    @ObservedObject var scheduler: Scheduler

    @State private var draft = ScheduleConfig(
        version: 1, masterActive: true, allowedWindows: [], quietPeriods: []
    )
    @State private var validationHint = ""
    @State private var isValid = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Master Active", isOn: $draft.masterActive)
                    .toggleStyle(.switch)

                GroupBox("Allowed Windows") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(draft.allowedWindows.indices, id: \.self) { i in
                            WindowRow(window: $draft.allowedWindows[i]) {
                                draft.allowedWindows.remove(at: i)
                            }
                            if i < draft.allowedWindows.count - 1 { Divider() }
                        }
                        Button("Add Window") { addWindow() }
                            .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }

                GroupBox("Quiet Periods") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(draft.quietPeriods.indices, id: \.self) { i in
                            QuietPeriodRow(quiet: $draft.quietPeriods[i]) {
                                draft.quietPeriods.remove(at: i)
                            }
                            if i < draft.quietPeriods.count - 1 { Divider() }
                        }
                        Button("Add Quiet Period") { addQuietPeriod() }
                            .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 4)
                }

                if !validationHint.isEmpty {
                    Text(validationHint)
                        .foregroundColor(.red)
                        .font(.caption)
                }

                HStack {
                    Button("Save") { saveDraft() }
                        .disabled(!isValid)
                        .keyboardShortcut(.return)
                    Spacer()
                }

                Divider()

                Text(scheduler.statusText)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
        }
        .onAppear { loadDraft() }
        .onChange(of: draft) { _ in validateDraft() }
    }

    private func loadDraft() {
        if let config = try? ScheduleStore.load(from: scheduleURL) {
            draft = config
        }
        validateDraft()
    }

    private func validateDraft() {
        do {
            try ScheduleStore.validate(draft)
            validationHint = ""
            isValid = true
        } catch ScheduleValidationError.emptyAllowedWindows {
            validationHint = "Add at least one window, or pause TAVS from the menu bar"
            isValid = false
        } catch ScheduleValidationError.emptyId {
            validationHint = "Window or quiet period has an empty ID"
            isValid = false
        } catch ScheduleValidationError.emptyDays(let windowId) {
            validationHint = "Select at least one day for \"\(windowId)\""
            isValid = false
        } catch ScheduleValidationError.invalidTime(let id, let value) {
            validationHint = "Invalid time \"\(value)\" in \"\(id)\" — use HH:MM format"
            isValid = false
        } catch ScheduleValidationError.zeroLengthWindow(let windowId) {
            validationHint = "Start and end are the same in \"\(windowId)\""
            isValid = false
        } catch ScheduleValidationError.invalidMinuteRange(let quietId, let value) {
            validationHint = "Minute \(value) out of range [0–59] in \"\(quietId)\""
            isValid = false
        } catch {
            validationHint = error.localizedDescription
            isValid = false
        }
    }

    private func saveDraft() {
        let dir = scheduleURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        } catch {
            let nsErr = error as NSError
            if nsErr.code != NSFileWriteFileExistsError {
                TAVSLog.scheduleStore.error("schedule dir create failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        do {
            try ScheduleStore.save(draft, to: scheduleURL)
        } catch {
            TAVSLog.scheduleStore.error("schedule save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func addWindow() {
        let index = draft.allowedWindows.count + 1
        draft.allowedWindows.append(
            TimeWindow(
                id: "window-\(index)",
                enabled: true,
                days: [.mon, .tue, .wed, .thu, .fri],
                start: "08:00",
                end: "20:00"
            )
        )
    }

    private func addQuietPeriod() {
        let index = draft.quietPeriods.count + 1
        draft.quietPeriods.append(
            QuietPeriod(
                id: "quiet-\(index)",
                enabled: true,
                kind: .hourly,
                startMinute: 50,
                endMinute: 59
            )
        )
    }
}

// MARK: - Window Row

private struct WindowRow: View {
    @Binding var window: TimeWindow
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: $window.enabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                TextField("ID", text: $window.id)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            HStack(spacing: 4) {
                ForEach(Day.allCases, id: \.self) { day in
                    Toggle(
                        String(day.rawValue.prefix(2)).capitalized,
                        isOn: dayBinding(day)
                    )
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
            }
            HStack {
                Text("Start:")
                    .frame(width: 40, alignment: .trailing)
                TextField("HH:MM", text: $window.start)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                Text("End:")
                    .frame(width: 30, alignment: .trailing)
                TextField("HH:MM", text: $window.end)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
            }
        }
    }

    private func dayBinding(_ day: Day) -> Binding<Bool> {
        Binding(
            get: { window.days.contains(day) },
            set: { isOn in
                if isOn && !window.days.contains(day) {
                    window.days.append(day)
                } else if !isOn {
                    window.days.removeAll { $0 == day }
                }
            }
        )
    }
}

// MARK: - Quiet Period Row

private struct QuietPeriodRow: View {
    @Binding var quiet: QuietPeriod
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle("", isOn: $quiet.enabled)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                Picker("", selection: $quiet.kind) {
                    Text("Hourly").tag(QuietKind.hourly)
                    Text("Fixed Daily").tag(QuietKind.fixedDaily)
                }
                .labelsHidden()
                .frame(width: 130)
                TextField("ID", text: $quiet.id)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                Spacer()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Group {
                switch quiet.kind {
                case .hourly:
                    HStack {
                        Text("Start minute:")
                            .frame(width: 90, alignment: .trailing)
                        TextField("0–59", value: optionalIntBinding(\.startMinute), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                        Text("End minute:")
                            .frame(width: 80, alignment: .trailing)
                        TextField("0–59", value: optionalIntBinding(\.endMinute), format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 50)
                    }
                case .fixedDaily:
                    HStack {
                        Text("Start:")
                            .frame(width: 40, alignment: .trailing)
                        TextField("HH:MM", text: optionalStringBinding(\.start))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("End:")
                            .frame(width: 30, alignment: .trailing)
                        TextField("HH:MM", text: optionalStringBinding(\.end))
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                    }
                }
            }
        }
    }

    private func optionalIntBinding(
        _ keyPath: WritableKeyPath<QuietPeriod, Int?>
    ) -> Binding<Int> {
        Binding(
            get: { quiet[keyPath: keyPath] ?? 0 },
            set: { quiet[keyPath: keyPath] = $0 }
        )
    }

    private func optionalStringBinding(
        _ keyPath: WritableKeyPath<QuietPeriod, String?>
    ) -> Binding<String> {
        Binding(
            get: { quiet[keyPath: keyPath] ?? "" },
            set: { quiet[keyPath: keyPath] = $0 }
        )
    }
}

// MARK: - Appearance Tab

private struct AppearanceTab: View {
    let userConfURL: URL

    @State private var themePreset = "nord"
    @State private var titleMode = "skip-processing"
    @State private var faceMode = "standard"
    @State private var compactTheme = "squares"
    @State private var stylishBackgrounds = false
    @State private var lightDarkSwitching = false
    @State private var pauseBgDark = Color(hex: UserConfStore.defaultPauseBgDark)
    @State private var pauseBgLight = Color(hex: UserConfStore.defaultPauseBgLight)
    @State private var initialized = false

    private static let themePresets = [
        "nord", "dracula", "solarized-dark", "solarized-light", "tokyo-night",
        "catppuccin-latte", "catppuccin-frappe", "catppuccin-macchiato", "catppuccin-mocha",
    ]

    private static let titleModes = [
        ("skip-processing", "Skip Processing"),
        ("prefix-only", "Prefix Only"),
        ("full", "Full"),
        ("off", "Off"),
    ]

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Theme Preset", selection: $themePreset) {
                    ForEach(Self.themePresets, id: \.self) { preset in
                        Text(preset.localizedCapitalized).tag(preset)
                    }
                }

                Picker("Title Mode", selection: $titleMode) {
                    ForEach(Self.titleModes, id: \.0) { (value, label) in
                        Text(label).tag(value)
                    }
                }
            }

            Section("Faces") {
                Picker("Face Mode", selection: $faceMode) {
                    Text("Standard").tag("standard")
                    Text("Compact").tag("compact")
                }

                Picker("Compact Theme", selection: $compactTheme) {
                    Text("Squares").tag("squares")
                    Text("Semantic").tag("semantic")
                    Text("Circles").tag("circles")
                    Text("Mixed").tag("mixed")
                }
                .disabled(faceMode != "compact")
            }

            Section("Effects") {
                Toggle("Stylish Backgrounds", isOn: $stylishBackgrounds)
                Toggle("Light/Dark Switching", isOn: $lightDarkSwitching)
            }

            Section("Paused State") {
                ColorPicker("Dark mode background", selection: $pauseBgDark, supportsOpacity: false)
                ColorPicker("Light mode background", selection: $pauseBgLight, supportsOpacity: false)
                Text("Used as the terminal background while TAVS is paused. The colour is picked from the macOS system appearance at the moment TAVS enters pause.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { loadFromStore() }
        .onDisappear { saveIfChanged() }
    }

    private func loadFromStore() {
        guard let store = try? UserConfStore(url: userConfURL) else { return }
        themePreset = store.themePreset ?? "nord"
        titleMode = store.titleMode ?? "skip-processing"
        faceMode = store.faceMode ?? "standard"
        compactTheme = store.compactTheme ?? "squares"
        stylishBackgrounds = store.stylishBackgrounds ?? false
        lightDarkSwitching = store.lightDarkSwitching ?? false
        pauseBgDark = Color(hex: store.pauseBgDark ?? UserConfStore.defaultPauseBgDark)
        pauseBgLight = Color(hex: store.pauseBgLight ?? UserConfStore.defaultPauseBgLight)
        DispatchQueue.main.async { initialized = true }
    }

    private func saveIfChanged() {
        guard initialized else { return }
        guard let store = try? UserConfStore(url: userConfURL) else { return }
        var changed = false
        if themePreset != (store.themePreset ?? "nord") { store.themePreset = themePreset; changed = true }
        if titleMode != (store.titleMode ?? "skip-processing") { store.titleMode = titleMode; changed = true }
        if faceMode != (store.faceMode ?? "standard") { store.faceMode = faceMode; changed = true }
        if compactTheme != (store.compactTheme ?? "squares") { store.compactTheme = compactTheme; changed = true }
        if stylishBackgrounds != (store.stylishBackgrounds ?? false) { store.stylishBackgrounds = stylishBackgrounds; changed = true }
        if lightDarkSwitching != (store.lightDarkSwitching ?? false) { store.lightDarkSwitching = lightDarkSwitching; changed = true }

        let darkHex = pauseBgDark.hexString()
        let lightHex = pauseBgLight.hexString()
        if darkHex != (store.pauseBgDark ?? UserConfStore.defaultPauseBgDark) {
            store.pauseBgDark = darkHex
            changed = true
        }
        if lightHex != (store.pauseBgLight ?? UserConfStore.defaultPauseBgLight) {
            store.pauseBgLight = lightHex
            changed = true
        }

        if changed {
            do {
                try store.save()
            } catch {
                TAVSLog.userConfStore.error("user.conf save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Color <-> hex helpers (for OSC 11 round-trip)

private extension Color {
    // Parses `#RRGGBB`. Fails over to mid-grey so a malformed user.conf value
    // cannot brick the ColorPicker binding.
    init(hex: String) {
        let trimmed = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else {
            self = Color(red: 0.23, green: 0.23, blue: 0.23)
            return
        }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }

    // Converts via the sRGB colour space so the round-trip matches what OSC 11
    // renders in a terminal (24-bit sRGB). `NSColor(.displayP3...).usingColorSpace`
    // clamps out-of-gamut values rather than failing, which keeps the picker
    // forgiving.
    func hexString() -> String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.gray
        let r = Int((ns.redComponent * 255.0).rounded())
        let g = Int((ns.greenComponent * 255.0).rounded())
        let b = Int((ns.blueComponent * 255.0).rounded())
        return String(format: "#%02X%02X%02X",
                      max(0, min(255, r)),
                      max(0, min(255, g)),
                      max(0, min(255, b)))
    }
}

// MARK: - Identity Tab

private struct IdentityTab: View {
    let userConfURL: URL

    @State private var identityMode = "dual"
    @State private var dirIconType = "flags"
    @State private var initialized = false

    var body: some View {
        Form {
            Section("Session Identity") {
                Picker("Identity Mode", selection: $identityMode) {
                    Text("Dual (flag + animal)").tag("dual")
                    Text("Single (animal only)").tag("single")
                    Text("Off").tag("off")
                }

                Picker("Directory Icon Type", selection: $dirIconType) {
                    Text("Flags").tag("flags")
                    Text("Plants").tag("plants")
                    Text("Buildings").tag("buildings")
                    Text("Auto").tag("auto")
                }
                .disabled(identityMode != "dual")
            }
        }
        .formStyle(.grouped)
        .onAppear { loadFromStore() }
        .onDisappear { saveIfChanged() }
    }

    private func loadFromStore() {
        guard let store = try? UserConfStore(url: userConfURL) else { return }
        identityMode = store.identityMode ?? "dual"
        dirIconType = store.dirIconType ?? "flags"
        DispatchQueue.main.async { initialized = true }
    }

    private func saveIfChanged() {
        guard initialized else { return }
        guard let store = try? UserConfStore(url: userConfURL) else { return }
        var changed = false
        if identityMode != (store.identityMode ?? "dual") { store.identityMode = identityMode; changed = true }
        if dirIconType != (store.dirIconType ?? "flags") { store.dirIconType = dirIconType; changed = true }
        if changed {
            do {
                try store.save()
            } catch {
                TAVSLog.userConfStore.error("user.conf save failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
