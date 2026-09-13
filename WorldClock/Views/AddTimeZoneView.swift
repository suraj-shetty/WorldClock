import SwiftUI

struct AddTimeZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    var title: String = "Add City"
    var onSelect: (_ identifier: String, _ label: String) -> Void

    private var filteredOptions: [TimeZoneOption] {
        guard !searchText.isEmpty else { return AddTimeZoneView.allOptions }
        return AddTimeZoneView.allOptions.filter { $0.label.localizedCaseInsensitiveContains(searchText) }
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
                            Button {
                                onSelect(option.identifier, option.label)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(option.label)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(Theme.textBright)
                                    Spacer()
                                }
                                .padding(.horizontal, 15)
                                .padding(.vertical, 14)
                                .background(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).fill(Theme.glass.opacity(0.48)))
                                .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.text.opacity(0.13), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.base)
                    .padding(.bottom, Theme.Spacing.lg)
                }
            }
        }
        #if os(macOS)
        // macOS sizes a .sheet to its content's ideal size rather than filling the
        // window like iOS does — without an explicit frame here, the content
        // gets no definite height and silently collapses to zero.
        .frame(minWidth: 420, idealWidth: 480, minHeight: 480, idealHeight: 560)
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

            Text(title)
                .font(.system(size: 22, weight: .medium))
                .tracking(-0.4)
                .foregroundStyle(Theme.text)

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
            TextField("", text: $searchText, prompt: Text("Search timezones").foregroundStyle(Theme.text.opacity(0.4)))
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
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.row, style: .continuous).stroke(Theme.text.opacity(0.13), lineWidth: 1))
        .padding(.horizontal, Theme.Spacing.base)
    }
}

private struct TimeZoneOption: Identifiable {
    let label: String
    let identifier: String
    var id: String { "\(label)|\(identifier)" }
}

private extension AddTimeZoneView {
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
