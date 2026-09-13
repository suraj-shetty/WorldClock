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
        NavigationStack {
            List(filteredOptions) { option in
                Button {
                    onSelect(option.identifier, option.label)
                    dismiss()
                } label: {
                    Text(option.label)
                        .foregroundStyle(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "Search timezones")
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        #if os(macOS)
        // macOS sizes a .sheet to its content's ideal size rather than filling the
        // window like iOS does — without an explicit frame here, the List inside
        // gets no definite height and silently collapses to zero (its rows still
        // exist, just with a 0pt-tall scroll area, so nothing is visible).
        .frame(minWidth: 420, idealWidth: 480, minHeight: 480, idealHeight: 560)
        #endif
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
