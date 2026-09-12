import SwiftUI

struct AddTimeZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    var onAdd: (_ identifier: String, _ label: String) -> Void

    private var filteredIdentifiers: [String] {
        let all = TimeZone.knownTimeZoneIdentifiers.sorted()
        guard !searchText.isEmpty else { return all }
        return all.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredIdentifiers, id: \.self) { identifier in
                Button {
                    onAdd(identifier, displayLabel(for: identifier))
                    dismiss()
                } label: {
                    Text(displayLabel(for: identifier))
                        .foregroundStyle(.primary)
                }
            }
            .searchable(text: $searchText, prompt: "Search timezones")
            .navigationTitle("Add City")
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

    private func displayLabel(for identifier: String) -> String {
        identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") } ?? identifier
    }
}
