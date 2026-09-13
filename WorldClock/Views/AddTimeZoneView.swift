import SwiftUI

/// Doubles as the "Add a city" sheet (multi-select: tap "+" repeatedly, then Done)
/// and the Settings "Home City" picker (single-select: tap a row to choose and dismiss).
struct AddTimeZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var addedLabels: Set<String> = []

    var kicker: String
    var title: String
    var isMultiSelect: Bool = true
    var existingLabels: Set<String> = []
    var homeTimeZone: TimeZone = .current
    var use24Hour: Bool = false
    var now: Date = Date()
    var onSelect: (_ identifier: String, _ label: String) -> Void

    private var filteredOptions: [TimeZoneOption] {
        guard !searchText.isEmpty else { return AddTimeZoneView.allOptions }
        return AddTimeZoneView.allOptions.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
                || ($0.country?.name.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            VStack(spacing: 16) {
                header
                searchField

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(filteredOptions) { option in
                            row(for: option)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.lg)
                }

                if isMultiSelect {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(Theme.accentText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.accent, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.base)
                }
            }
        }
        #if os(macOS)
        // macOS sizes a .sheet to its content's ideal size rather than filling the
        // window like iOS does — without an explicit frame here, the content
        // gets no definite height and silently collapses to zero.
        .frame(minWidth: 420, idealWidth: 480, minHeight: 480, idealHeight: 620)
        #endif
    }

    private func row(for option: TimeZoneOption) -> some View {
        let isAdded = isMultiSelect && (existingLabels.contains(option.label) || addedLabels.contains(option.label))
        // Resolved once, through the same cache ClockEntry.timeZone uses — this view
        // previously constructed a fresh, uncached TimeZone twice per row (once here,
        // once in subtitle(for:)) on every render of a ~450-row list.
        let zone = TimeZoneResolver.resolve(option.identifier)
        let time = timeComponents(in: zone)

        let content = HStack(spacing: 12) {
            if let country = option.country {
                Text(country.flag).font(.system(size: 26))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(option.label)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textBright)
                Text(subtitle(for: option, in: zone))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text.opacity(0.6))
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            (
                Text(time.main).font(.system(size: 20, weight: .medium))
                + Text(time.period.isEmpty ? "" : " " + time.period).font(.system(size: 12, weight: .medium))
            )
            .monospacedDigit()
            .foregroundStyle(Theme.textBright)

            if isMultiSelect {
                Button {
                    onSelect(option.identifier, option.label)
                    addedLabels.insert(option.label)
                } label: {
                    Image(systemName: isAdded ? "checkmark" : "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isAdded ? Theme.accent.opacity(0.6) : Theme.accentText)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Theme.glass.opacity(0.5)))
                        .overlay(Circle().stroke(isAdded ? Theme.accent.opacity(0.3) : Theme.accent, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isAdded)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.48)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.text.opacity(0.13), lineWidth: 1))

        return Group {
            if isMultiSelect {
                content
            } else {
                Button {
                    onSelect(option.identifier, option.label)
                    dismiss()
                } label: {
                    content
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.accentText)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Theme.glass.opacity(0.5)))
                    .overlay(Circle().stroke(Theme.accent, lineWidth: 1))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text(kicker)
                    .font(.system(size: 10.5, weight: .medium))
                    .tracking(1.5)
                    .foregroundStyle(Theme.accentText)
                Text(title)
                    .font(.system(size: 29, weight: .medium))
                    .tracking(-0.5)
                    .foregroundStyle(Theme.text)
            }

            Spacer()
        }
        .padding(.horizontal, Theme.Spacing.base)
        .padding(.top, 12)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text.opacity(0.5))
            TextField("", text: $searchText, prompt: Text("City or country").foregroundStyle(Theme.text.opacity(0.4)))
                .foregroundStyle(Theme.textBright)
                .tint(Theme.accent)
            #if os(iOS)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            #endif
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.text.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.base)
    }

    /// Split so the "AM"/"PM" suffix can render smaller than the digits (empty in 24h mode).
    private func timeComponents(in zone: TimeZone) -> (main: String, period: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let comps = calendar.dateComponents([.hour, .minute], from: now)
        let hour = comps.hour ?? 0, minute = comps.minute ?? 0
        if use24Hour { return (String(format: "%02d:%02d", hour, minute), "") }
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        return (String(format: "%d:%02d", displayHour, minute), hour < 12 ? "AM" : "PM")
    }

    private func subtitle(for option: TimeZoneOption, in zone: TimeZone) -> String {
        let countryName = option.country?.name
        let homeOffset = homeTimeZone.secondsFromGMT(for: now)
        let zoneOffset = zone.secondsFromGMT(for: now)
        let diffMinutes = (zoneOffset - homeOffset) / 60
        let offsetText: String
        if diffMinutes == 0 {
            offsetText = "Home"
        } else {
            let sign = diffMinutes > 0 ? "+" : "\u{2212}"
            let magnitude = abs(diffMinutes)
            let hours = magnitude / 60, minutes = magnitude % 60
            // Rounded, not truncated — see the identical fix in ClockListView.deltaLabel.
            let tenths = Int((Double(minutes) / 6).rounded())
            offsetText = minutes == 0 ? "\(sign)\(hours)h" : "\(sign)\(hours).\(tenths)h"
        }
        return [countryName, offsetText].compactMap { $0 }.joined(separator: " · ")
    }
}

struct TimeZoneOption: Identifiable {
    let label: String
    let identifier: String
    var id: String { "\(label)|\(identifier)" }
    var country: (name: String, flag: String)? { ClockEntry.lookupCountry(for: identifier) }
}

extension AddTimeZoneView {
    /// IANA identifiers name one representative city per zone, so a country with a
    /// single nationwide zone but several huge cities — India's `Asia/Kolkata`, say —
    /// otherwise has no way to search for "Bengaluru" or "Delhi" even though both
    /// keep that exact time. These aliases add searchable rows for major cities that
    /// share an existing zone, without inventing new timezones: picking one still
    /// stores the real IANA identifier, just under the city name people actually type.
    static let cityAliases: [(label: String, identifier: String)] = [
        // India — Asia/Kolkata
        ("Bengaluru", "Asia/Kolkata"), ("Bangalore", "Asia/Kolkata"), ("Delhi", "Asia/Kolkata"),
        ("New Delhi", "Asia/Kolkata"), ("Mumbai", "Asia/Kolkata"), ("Chennai", "Asia/Kolkata"),
        ("Hyderabad", "Asia/Kolkata"), ("Pune", "Asia/Kolkata"), ("Ahmedabad", "Asia/Kolkata"),
        ("Jaipur", "Asia/Kolkata"), ("Surat", "Asia/Kolkata"), ("Lucknow", "Asia/Kolkata"),
        ("Kanpur", "Asia/Kolkata"), ("Nagpur", "Asia/Kolkata"), ("Indore", "Asia/Kolkata"),
        ("Bhopal", "Asia/Kolkata"), ("Visakhapatnam", "Asia/Kolkata"), ("Patna", "Asia/Kolkata"),
        ("Vadodara", "Asia/Kolkata"), ("Coimbatore", "Asia/Kolkata"),
        // China — Asia/Shanghai
        ("Beijing", "Asia/Shanghai"), ("Guangzhou", "Asia/Shanghai"), ("Shenzhen", "Asia/Shanghai"),
        ("Chengdu", "Asia/Shanghai"), ("Chongqing", "Asia/Shanghai"), ("Tianjin", "Asia/Shanghai"),
        ("Wuhan", "Asia/Shanghai"), ("Xi'an", "Asia/Shanghai"), ("Hangzhou", "Asia/Shanghai"),
        ("Nanjing", "Asia/Shanghai"),
    ]

    static let allOptions: [TimeZoneOption] = {
        let canonical = TimeZone.knownTimeZoneIdentifiers.map { identifier in
            TimeZoneOption(label: displayLabel(for: identifier), identifier: identifier)
        }
        let aliases = cityAliases.map { TimeZoneOption(label: $0.label, identifier: $0.identifier) }
        return (canonical + aliases).sorted { $0.label.localizedCompare($1.label) == .orderedAscending }
    }()

    static func displayLabel(for identifier: String) -> String {
        identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }
}
