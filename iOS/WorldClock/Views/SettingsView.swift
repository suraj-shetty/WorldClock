import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @AppStorage("use24Hour") private var use24Hour = false
    @AppStorage("showCountryName") private var showCountryName = true
    @AppStorage("animateSky") private var animateSky = true
    @AppStorage("flagNextDayCities") private var flagNextDayCities = false
    @AppStorage("snapMinutes") private var snapMinutes = 15
    @AppStorage("homeTimeZoneIdentifier") private var homeTimeZoneIdentifier = ""

    @State private var showingHomePicker = false

    private var homeTimeZone: TimeZone {
        homeTimeZoneIdentifier.isEmpty ? .current : (TimeZone(identifier: homeTimeZoneIdentifier) ?? .current)
    }

    private var homeLabel: String { ClockFormatting.displayLabel(for: homeTimeZone.identifier) }

    var body: some View {
        ZStack {
            Theme.ground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    section("Home") {
                        Button {
                            showingHomePicker = true
                        } label: {
                            HStack(spacing: 12) {
                                if let country = ClockEntry.lookupCountry(for: homeTimeZone.identifier) {
                                    Text(country.flag).font(.system(size: 22))
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(homeLabel)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(Theme.textBright)
                                    Text(homeSubtitle)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.text.opacity(0.62))
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Theme.text.opacity(0.5))
                            }
                            .padding(15)
                            .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.5)))
                            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.accent.opacity(0.5), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    section("Clock") {
                        VStack(spacing: 10) {
                            toggleRow("Use 24-hour time", "Times and wheel ticks read 18:30 instead of 6:30 PM.", isOn: $use24Hour)
                            toggleRow("Show country name", "Adds the country beside each city's offset.", isOn: $showCountryName)
                            toggleRow("Animate the sky", "The illustration follows the scrubbed time as you drag.", isOn: $animateSky)
                            toggleRow("Flag next-day cities", "Marks rows whose local date is ahead of home.", isOn: $flagNextDayCities)
                        }
                    }

                    section("Scrub snaps to") {
                        HStack(spacing: 4) {
                            snapOption(15)
                            snapOption(30)
                            snapOption(60)
                        }
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.5)))
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.text.opacity(0.13), lineWidth: 1))
                    }

                    section("About") {
                        VStack(spacing: 10) {
                            infoRow("Version", versionString)
                            infoRow("Time zone data", "IANA 2026a")
                        }
                    }
                }
                .padding(Theme.Spacing.base)
                .padding(.bottom, Theme.Spacing.lg)
            }
        }
        .sheet(isPresented: $showingHomePicker) {
            AddTimeZoneView(
                kicker: "HOME TIMEZONE",
                title: "Choose home city",
                isMultiSelect: false,
                homeTimeZone: homeTimeZone,
                use24Hour: use24Hour
            ) { identifier, _ in
                homeTimeZoneIdentifier = identifier
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, idealWidth: 480, minHeight: 560, idealHeight: 640)
        #endif
    }

    private var header: some View {
        HStack {
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

            Text("Settings")
                .font(.system(size: 29, weight: .medium))
                .tracking(-0.5)
                .foregroundStyle(Theme.text)

            Spacer()
        }
        .padding(.top, 8)
    }

    private var homeSubtitle: String {
        let name = ClockEntry.lookupCountry(for: homeTimeZone.identifier)?.name
        let suffix = "all offsets are measured from here"
        return name.map { "\($0) · \(suffix)" } ?? suffix.prefix(1).uppercased() + suffix.dropFirst()
    }

    private var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Theme.accentText)
            content()
        }
    }

    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textBright)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.text.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.accent)
        .padding(15)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.text.opacity(0.13), lineWidth: 1))
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.textBright)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text.opacity(0.6))
        }
        .padding(15)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.text.opacity(0.13), lineWidth: 1))
    }

    private func snapOption(_ minutes: Int) -> some View {
        Button {
            snapMinutes = minutes
        } label: {
            Text("\(minutes) min")
                .font(.system(size: 15, weight: .medium))
                .tracking(-0.15)
                .foregroundStyle(snapMinutes == minutes ? Theme.textBrightest : Theme.text.opacity(0.66))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(snapMinutes == minutes ? Theme.accent.opacity(0.28) : .clear)
                )
        }
        .buttonStyle(.plain)
    }
}
