#if os(macOS)
import SwiftUI
import ServiceManagement

// The Mac's Settings window and Add City dialog, built to the canvas's Settings and
// Add City boards. iPhone/iPad keep SettingsView and AddTimeZoneView: the Mac design
// is a tabbed preferences window and a keyboard-first dialog, not full-screen sheets.

// MARK: - Settings

struct MacSettingsView: View {
    var body: some View {
        TabView {
            MacGeneralSettings().tabItem { Label("General", systemImage: "clock") }
            MacMenuBarSettings().tabItem { Label("Menu Bar", systemImage: "menubar.rectangle") }
            MacAboutSettings().tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 672)
        .background(Theme.ground)
        .environment(\.colorScheme, .dark)
    }
}

private struct MacGeneralSettings: View {
    @AppStorage("use24Hour") private var use24Hour = false
    @AppStorage("showCountryName") private var showCountryName = true
    @AppStorage("animateSky") private var animateSky = true
    @AppStorage("flagNextDayCities") private var flagNextDayCities = false
    @AppStorage("snapMinutes") private var snapMinutes = 15
    @AppStorage("homeTimeZoneIdentifier") private var homeTimeZoneIdentifier = ""
    @AppStorage("homeTimeZoneLabel") private var homeTimeZoneLabel = ""
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @State private var showingHomePicker = false
    @State private var loginItemRefresh = false

    private var homeZone: TimeZone { ClockFormatting.homeZone(homeTimeZoneIdentifier) }

    /// Backed by the system's login-item record, not a stored flag, so it can't drift
    /// from what System Settings › General › Login Items shows.
    private var openAtLogin: Binding<Bool> {
        Binding(
            get: { _ = loginItemRefresh; return SMAppService.mainApp.status == .enabled },
            set: { enabled in
                try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                loginItemRefresh.toggle()
            }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SettingsGroup("Home") {
                    SettingsRow {
                        Text(ClockEntry.lookupCountry(for: homeZone.identifier)?.flag ?? "").font(.system(size: 22))
                        rowText(ClockFormatting.homeLabel(identifier: homeTimeZoneIdentifier, label: homeTimeZoneLabel),
                                [ClockEntry.lookupCountry(for: homeZone.identifier)?.name, "all offsets are measured from here"]
                                    .compactMap { $0 }.joined(separator: " · "))
                        Button("Change…") { showingHomePicker = true }.buttonStyle(PillButtonStyle())
                    }
                }
                SettingsGroup("Clock") {
                    toggleRow("Use 24-hour time", "Times and wheel ticks read 18:30 instead of 6:30 PM.", $use24Hour)
                    RowDivider()
                    toggleRow("Show country name", "Adds the country beside each city's offset.", $showCountryName)
                    RowDivider()
                    toggleRow("Animate the sky", "The illustration follows the scrubbed time as you drag.", $animateSky)
                    RowDivider()
                    toggleRow("Flag next-day cities", "Marks rows whose local date is ahead of home.", $flagNextDayCities)
                }
                VStack(alignment: .leading, spacing: 6) {
                    SettingsHeading("Scrub snaps to")
                    HStack(spacing: 4) {
                        ForEach([15, 30, 60], id: \.self) { minutes in
                            let on = snapMinutes == minutes
                            Button { snapMinutes = minutes } label: {
                                Text("\(minutes) min")
                                    .font(.system(size: 13, weight: on ? .semibold : .regular))
                                    .foregroundStyle(on ? Color(hex: 0x14121f) : Theme.text)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 6)
                                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? Theme.accentLight : .clear))
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(on ? .isSelected : [])
                        }
                    }
                    .padding(4)
                    .settingsGroupBackground()
                }
                SettingsGroup("On this Mac") {
                    toggleRow("Show in menu bar", "Keep a city's time beside the system clock.", $showMenuBarExtra)
                    RowDivider()
                    toggleRow("Open at login", nil, openAtLogin)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 18)
            .padding(.bottom, 22)
        }
        .frame(height: 470)
        .sheet(isPresented: $showingHomePicker) {
            MacAddCityView(choosingHome: true, homeTimeZone: homeZone, use24Hour: use24Hour) { identifier, label in
                homeTimeZoneIdentifier = identifier
                homeTimeZoneLabel = label
            }
        }
    }
}

private struct MacMenuBarSettings: View {
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup("Menu bar") {
                toggleRow("Show in menu bar", "Keep a city's time beside the system clock.", $showMenuBarExtra)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .frame(height: 220)
    }
}

private struct MacAboutSettings: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup("About") {
                SettingsRow { rowText("Version", nil); valueText(versionString) }
                RowDivider()
                SettingsRow { rowText("Time zone data", nil); valueText(TimeZone.timeZoneDataVersion) }
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.top, 18)
        .frame(height: 220)
    }

    private var versionString: String {
        let info = Bundle.main.infoDictionary
        return "\(info?["CFBundleShortVersionString"] as? String ?? "1.0") (\(info?["CFBundleVersion"] as? String ?? "1"))"
    }

    private func valueText(_ value: String) -> some View {
        Text(value).font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.7))
    }
}

// MARK: Settings building blocks

private struct SettingsHeading: View {
    let title: String
    init(_ title: String) { self.title = title }
    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Theme.text.opacity(0.66))
            .padding(.leading, 4)
    }
}

/// A heading over a rounded group of rows; rows are separated with `RowDivider`.
private struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsHeading(title)
            VStack(spacing: 0) { content }
                .settingsGroupBackground()
        }
    }
}

private struct RowDivider: View {
    var body: some View { Rectangle().fill(.white.opacity(0.07)).frame(height: 1) }
}

private struct SettingsRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        HStack(spacing: 14) { content }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
    }
}

private extension View {
    func settingsGroupBackground() -> some View {
        background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.white.opacity(0.08), lineWidth: 1))
    }
}

private func rowText(_ title: String, _ subtitle: String?) -> some View {
    VStack(alignment: .leading, spacing: 1) {
        Text(title).font(.system(size: 13)).foregroundStyle(Theme.textBright)
        if let subtitle {
            Text(subtitle).font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.7))
        }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
}

private func toggleRow(_ title: String, _ subtitle: String?, _ isOn: Binding<Bool>) -> some View {
    SettingsRow {
        Toggle(isOn: isOn) { rowText(title, subtitle) }
            .toggleStyle(NocturneSwitch())
    }
}

/// The canvas's 34×20 switch: accent track when on, faint white when off.
private struct NocturneSwitch: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 14) {
            configuration.label
            Capsule()
                .fill(configuration.isOn ? Theme.accent : .white.opacity(0.18))
                .frame(width: 34, height: 20)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle().fill(.white).frame(width: 16, height: 16)
                        .shadow(color: .black.opacity(0.4), radius: 1.5, y: 1)
                        .padding(2)
                }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) { configuration.isOn.toggle() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

/// The canvas's secondary capsule button (Change…, Cancel).
struct PillButtonStyle: ButtonStyle {
    var prominent = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: prominent ? 13 : 12, weight: prominent ? .semibold : .regular))
            .foregroundStyle(prominent ? Color(hex: 0x0e0c1c) : Theme.text)
            .padding(.horizontal, prominent ? 16 : 12)
            .frame(height: prominent ? 30 : 26)
            .background(Capsule().fill(prominent ? Theme.accent : .white.opacity(0.10)))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Capsule())
    }
}

// MARK: - Add City

/// The canvas's Add City dialog: a search field, a keyboard-driven result list, and
/// Cancel / Add buttons. ↑↓ move, ↩ adds and closes, ⌘↩ adds and keeps it open, esc clears.
/// With `choosingHome` it picks the home city instead (no "Added" tags, closes on pick).
struct MacAddCityView: View {
    @Environment(\.dismiss) private var dismiss
    var choosingHome = false
    var existingLabels: Set<String> = []
    var homeTimeZone: TimeZone
    var use24Hour: Bool
    var onSelect: (_ identifier: String, _ label: String) -> Void

    @State private var search = ""
    @State private var selected = 0
    @State private var added: Set<String> = []
    @FocusState private var searchFocused: Bool

    private var results: [TimeZoneOption] {
        guard !search.isEmpty else { return AddTimeZoneView.allOptions }
        return AddTimeZoneView.allOptions.filter {
            $0.label.localizedCaseInsensitiveContains(search)
                || ($0.country?.name.localizedCaseInsensitiveContains(search) ?? false)
        }
    }

    private var current: TimeZoneOption? {
        results.indices.contains(selected) ? results[selected] : nil
    }

    private func isAdded(_ option: TimeZoneOption) -> Bool {
        !choosingHome && (existingLabels.contains(option.label) || added.contains(option.label))
    }

    var body: some View {
        let rows = results
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(choosingHome ? "Choose Home City" : "Add City")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textBrightest)
                    Spacer()
                    Text("Search ~\(AddTimeZoneView.allOptions.count / 50 * 50) time zones by city or country")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text.opacity(0.68))
                }
                searchField
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            ScrollViewReader { proxy in
                ScrollView {
                    TimelineView(.periodic(from: .now, by: 60)) { timeline in
                        LazyVStack(spacing: 2) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, option in
                                resultRow(option, now: timeline.date, isSelected: index == selected)
                                    .id(index)
                                    .onTapGesture { selected = index }
                                    .onTapGesture(count: 2) { selected = index; commit(keepOpen: false) }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .onChange(of: selected) { _, index in proxy.scrollTo(index) }
            }

            HStack(spacing: 10) {
                Text(choosingHome ? "↑ ↓ to move · ↩ to choose" : "↑ ↓ to move · ↩ to add · ⌘↩ add & keep open")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text.opacity(0.68))
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(PillButtonStyle())
                    .frame(height: 30)
                    .keyboardShortcut(.cancelAction)
                Button(primaryTitle) { commit(keepOpen: false) }
                    .buttonStyle(PillButtonStyle(prominent: true))
                    .disabled(current.map(isAdded) ?? true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.10)).frame(height: 1) }
        }
        .frame(width: 560, height: 560)
        .background(Theme.glass.opacity(0.72))
        .background(.ultraThinMaterial)
        .environment(\.colorScheme, .dark)
        .onAppear { searchFocused = true }
        .onChange(of: search) { selected = 0 }
    }

    private var primaryTitle: String {
        guard let current else { return choosingHome ? "Choose" : "Add" }
        if isAdded(current) { return "Added" }
        return choosingHome ? "Use \(current.label)" : "Add \(current.label)"
    }

    private func commit(keepOpen: Bool) {
        guard let option = current, !isAdded(option) else { return }
        onSelect(option.identifier, option.label)
        added.insert(option.label)
        if !keepOpen || choosingHome { dismiss() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accentText)
            TextField("City or country", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(Theme.textBrightest)
                .focused($searchFocused)
                .onKeyPress(keys: [.upArrow, .downArrow, .return, .escape]) { press in
                    switch press.key {
                    case .upArrow: selected = max(selected - 1, 0)
                    case .downArrow: selected = min(selected + 1, max(results.count - 1, 0))
                    case .return: commit(keepOpen: press.modifiers.contains(.command))
                    default:
                        // esc clears first; with nothing to clear it falls through to Cancel.
                        guard !search.isEmpty else { return .ignored }
                        search = ""
                    }
                    return .handled
                }
            Text("esc to clear").font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .frame(height: 38)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.accentText.opacity(0.8), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Theme.accent.opacity(0.35), lineWidth: 3).padding(-3))
    }

    private func resultRow(_ option: TimeZoneOption, now: Date, isSelected: Bool) -> some View {
        let zone = TimeZone(identifier: option.identifier) ?? .current
        let time = ClockFormatting.timeComponents(at: now, in: zone, use24Hour: use24Hour)
        let day = ClockFormatting.dayOffset(of: zone, from: homeTimeZone, at: now)
        let offset = ClockFormatting.offsetLabel(homeOffsetSeconds: homeTimeZone.secondsFromGMT(for: now),
                                                 zoneOffsetSeconds: zone.secondsFromGMT(for: now))
        return ResultRowBackground(isSelected: isSelected) {
            HStack(spacing: 12) {
                Text(option.country?.flag ?? "").font(.system(size: 18)).frame(width: 24)
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.label).font(.system(size: 14)).foregroundStyle(Theme.textBright)
                    Text([option.country?.name, option.identifier].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.text.opacity(0.7))
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(time.main + (time.period.isEmpty ? "" : " " + time.period) + (day > 0 ? " · Tomorrow" : day < 0 ? " · Yesterday" : ""))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textBrightest)
                    Text(offset).font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.7))
                }
                .monospacedDigit()
                if isAdded(option) {
                    Text("Added")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x14121f))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Theme.accentLight))
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A result row's highlight: accent when selected, faint white on hover.
private struct ResultRowBackground<Content: View>: View {
    let isSelected: Bool
    @ViewBuilder var content: Content
    @State private var hovered = false

    var body: some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.38) : hovered ? .white.opacity(0.06) : .clear))
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
    }
}
#endif
