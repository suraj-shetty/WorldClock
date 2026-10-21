#if os(macOS)
import SwiftUI
import SwiftData

/// The Mac window, built to the canvas's Main window board: the sky full-bleed behind a
/// lit-glass sidebar, a three-column city board, and one persistent timeline bar
/// anchored to the selected city (or home). iPhone/iPad keep ClockListView; the Mac
/// design has its own type scale, a sun/moon arc per card and a different ruler.
struct MacBoardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClockEntry.sortOrder) private var entries: [ClockEntry]
    @State private var viewModel = ClockBoardViewModel()
    @State private var showingAddSheet = false
    @State private var showingSidebar = true
    @State private var filter = ""
    @State private var hoveringTimeline = false
    @State private var scrollMonitor: Any?
    @FocusState private var filterFocused: Bool
    @AppStorage("use24Hour") private var use24Hour = false
    @AppStorage("showCountryName") private var showCountryName = true
    @AppStorage("animateSky") private var animateSky = true
    @AppStorage("flagNextDayCities") private var flagNextDayCities = false
    @AppStorage("snapMinutes") private var snapMinutes = 15
    @AppStorage("homeTimeZoneIdentifier") private var homeTimeZoneIdentifier = ""
    @AppStorage("homeTimeZoneLabel") private var homeTimeZoneLabel = ""

    private var homeTimeZone: TimeZone { ClockFormatting.homeZone(homeTimeZoneIdentifier) }
    private var homeLabel: String { ClockFormatting.homeLabel(identifier: homeTimeZoneIdentifier, label: homeTimeZoneLabel) }
    private var selectedEntry: ClockEntry? { entries.first { $0.id == viewModel.selectedEntryID } }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let now = timeline.date
            let skyHour = animateSky
                ? viewModel.activeAnchorHour(entries: entries, now: now, homeTimeZone: homeTimeZone)
                : ClockFormatting.hourOfDay(in: homeTimeZone, at: now)

            ZStack {
                BackgroundView(hour: skyHour)
                HStack(alignment: .top, spacing: 0) {
                    if showingSidebar {
                        sidebar(now: now)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    VStack(spacing: 18) {
                        header(now: now)
                        board(now: now)
                        timelineBar(now: now)
                    }
                    .padding(.leading, showingSidebar ? 12 : 22)
                    .padding(.trailing, 22)
                    .padding(.top, showingSidebar ? 16 : 40)
                    .padding(.bottom, 18)
                }
            }
            .ignoresSafeArea()
            // The glass light moves in the same 15-minute steps as the snap, so the panes
            // don't re-render their shadows on every frame of a scrub (PLAN performance rule 1).
            .environment(\.glassLight, GlassLight(hour: (skyHour * 4).rounded() / 4, day: now))
        }
        .environment(\.colorScheme, .dark)
        .frame(minWidth: 760, minHeight: 560)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(.space) {
            guard viewModel.selectedEntryID != nil, !filterFocused else { return .ignored }
            withAnimation(.easeInOut(duration: 0.3)) { viewModel.deselect() }
            return .handled
        }
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
            guard !filterFocused else { return .ignored }
            step(press.key == .leftArrow ? -1 : 1)
            return .handled
        }
        .onDeleteCommand {
            if let entry = selectedEntry { viewModel.delete(entry, from: modelContext) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .addCityRequested)) { _ in showingAddSheet = true }
        .onAppear {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { swipe($0) }
        }
        .onDisappear {
            if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
        }
        .focusedSceneValue(\.boardActions, BoardActions(
            addCity: { showingAddSheet = true },
            now: { withAnimation(.easeOut(duration: 0.5)) { viewModel.offset = 0 } },
            step: { step($0) },
            toggleSidebar: { withAnimation(.easeInOut(duration: 0.25)) { showingSidebar.toggle() } },
            findCity: { showingSidebar = true; filterFocused = true }
        ))
        .task(id: entries.map(SharedCities.City.init)) { SharedCities.save(entries.map(SharedCities.City.init)) }
        .sheet(isPresented: $showingAddSheet) {
            MacAddCityView(
                existingLabels: Set(entries.map(\.label)),
                homeTimeZone: homeTimeZone,
                use24Hour: use24Hour
            ) { identifier, label in
                viewModel.add(identifier: identifier, label: label, after: entries, in: modelContext)
            }
        }
    }

    /// ← / → and ⌥← / ⌥→: one snap step, clamped to the wheel's ±48 h.
    private func step(_ direction: Int) {
        let limit: TimeInterval = 48 * 3600
        let target = viewModel.offset + Double(direction * snapMinutes) * 60
        withAnimation(.easeOut(duration: 0.3)) { viewModel.offset = min(max(target, -limit), limit) }
    }

    /// A two-finger horizontal swipe over the timeline scrubs it like a drag, at the
    /// ruler's 1.5 pt per minute, and snaps when the fingers lift. SwiftUI on macOS 14
    /// has no scroll-gesture API, hence the event monitor. Momentum is swallowed, so
    /// the snap isn't undone by the coast that follows it.
    private func swipe(_ event: NSEvent) -> NSEvent? {
        guard hoveringTimeline, event.hasPreciseScrollingDeltas else { return event }
        if event.momentumPhase != [] { return nil }
        guard abs(event.scrollingDeltaX) >= abs(event.scrollingDeltaY) || event.phase == .ended else { return event }
        let limit: TimeInterval = 48 * 3600, snap = Double(snapMinutes) * 60
        if event.phase == .ended || event.phase == .cancelled {
            let snapped = (viewModel.offset / snap).rounded() * snap
            withAnimation(.easeOut(duration: 0.3)) { viewModel.offset = min(max(snapped, -limit), limit) }
        } else {
            viewModel.offset = min(max(viewModel.offset - Double(event.scrollingDeltaX) / 1.5 * 60, -limit), limit)
        }
        return nil
    }

    // MARK: Sidebar

    private func sidebar(now: Date) -> some View {
        let shown = filter.isEmpty ? entries : entries.filter {
            $0.label.localizedCaseInsensitiveContains(filter)
                || ($0.country?.name.localizedCaseInsensitiveContains(filter) ?? false)
        }
        return VStack(alignment: .leading, spacing: 14) {
            // The window's own traffic lights sit here, where the canvas draws its three dots.
            Spacer().frame(height: 22)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.text.opacity(0.7))
                TextField("Filter cities", text: $filter)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .focused($filterFocused)
                Text("⌘F").font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.6))
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.white.opacity(0.07)))

            VStack(alignment: .leading, spacing: 2) {
                sidebarSection("Home")
                sidebarRow(label: homeLabel, zone: homeTimeZone, now: now, selected: false, isHome: true) {
                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.deselect() }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                sidebarSection("Cities")
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(shown) { entry in
                            sidebarRow(label: entry.label, zone: entry.timeZone, now: now, selected: viewModel.selectedEntryID == entry.id, isHome: false) {
                                withAnimation(.easeInOut(duration: 0.3)) { viewModel.select(entry) }
                            }
                            .contextMenu { deleteButton(entry) }
                        }
                    }
                }
                .scrollIndicators(.never)
            }
            .frame(maxHeight: .infinity, alignment: .top)

            Button { showingAddSheet = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold))
                    Text("Add City…")
                    Spacer()
                    Text("⌘N").font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.6))
                }
                .font(.system(size: 13))
                .foregroundStyle(Theme.accentText)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 14)
        .frame(width: 248)
        .frame(maxHeight: .infinity)
        .litGlass(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(10)
    }

    private func sidebarSection(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Theme.text.opacity(0.62))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
    }

    private func sidebarRow(label: String, zone: TimeZone, now: Date, selected: Bool, isHome: Bool, action: @escaping () -> Void) -> some View {
        let time = ClockFormatting.timeComponents(at: viewModel.displayDate(now: now), in: zone, use24Hour: use24Hour)
        return Button(action: action) {
            HStack(spacing: 10) {
                if isHome {
                    Image(systemName: "house").font(.system(size: 13)).foregroundStyle(Theme.accentText)
                }
                Text(label).font(.system(size: 13)).lineLimit(1)
                Spacer(minLength: 6)
                Text(time.main + (time.period.isEmpty ? "" : " " + time.period))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .opacity(isHome ? 0.72 : 0.75)
            }
            .foregroundStyle(selected ? Theme.textBrightest : Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(selected ? Theme.accent.opacity(0.38) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Header

    private func header(now: Date) -> some View {
        let shown = viewModel.displayDate(now: now)
        let style = Date.FormatStyle(timeZone: homeTimeZone)
        let kicker = "\(shown.formatted(style.weekday(.wide))) · \(shown.formatted(style.month(.abbreviated).day())) · Home · \(homeLabel)"
        return HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(kicker)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.88)
                    .textCase(.uppercase)
                    .foregroundStyle(Color(hex: 0xd6d0ff))
                Text("World Clock")
                    .font(.system(size: 28, weight: .medium))
                    .tracking(-0.28)
                    .foregroundStyle(Theme.textBrightest)
            }
            .shadow(color: Color(hex: 0x090b18).opacity(0.55), radius: 6, y: 1)
            Spacer()
            HStack(spacing: 8) {
                formatToggle
                Button { withAnimation(.easeOut(duration: 0.5)) { viewModel.offset = 0 } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.accentText)
                        Text("Now").font(.system(size: 13)).foregroundStyle(Theme.textBright)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .litGlass(Capsule())
                }
                .buttonStyle(.plain)
                glassCircleButton("plus", label: "Add city") { showingAddSheet = true }
                SettingsLink { glassCircle("gearshape") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Settings")
            }
        }
    }

    private var formatToggle: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { is24 in
                let on = use24Hour == is24
                Button { use24Hour = is24 } label: {
                    Text(is24 ? "24h" : "12h")
                        .font(.system(size: 12, weight: on ? .semibold : .regular))
                        .foregroundStyle(on ? Color(hex: 0x14121f) : Theme.text)
                        .padding(.horizontal, 12)
                        .frame(height: 26)
                        .background(Capsule().fill(on ? Theme.accentLight : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(3)
        .litGlass(Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clock format")
    }

    private func glassCircle(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.accentText)
            .frame(width: 32, height: 32)
            .litGlass(Circle())
            .contentShape(Circle())
    }

    private func glassCircleButton(_ systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { glassCircle(systemImage) }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    // MARK: Board

    private func board(now: Date) -> some View {
        GeometryReader { geometry in
            ScrollView {
                // The canvas lays out three columns of at least 260 pt; fewer only when they don't fit.
                let count = min(3, max(1, Int((geometry.size.width + 12) / 272)))
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Array(ClockListView.columns(entries, count: count).enumerated()), id: \.offset) { _, column in
                        LazyVStack(spacing: 12) {
                            ForEach(column) { entry in
                                MacCityCard(
                                    entry: entry,
                                    displayDate: viewModel.displayDate(now: now),
                                    homeTimeZone: homeTimeZone,
                                    use24Hour: use24Hour,
                                    showCountryName: showCountryName,
                                    flagsDays: flagNextDayCities,
                                    isSelected: viewModel.selectedEntryID == entry.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.3)) { viewModel.select(entry) }
                                }
                                .contextMenu { deleteButton(entry) }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                // Room for the cards' glass shadows, which the scroll view would otherwise clip.
                .padding(.bottom, 24)
            }
            .scrollIndicators(.never)
            .scrollClipDisabled()
        }
    }

    // MARK: Timeline

    private func timelineBar(now: Date) -> some View {
        let zone = viewModel.anchorTimeZone(entries: entries, deviceTimeZone: homeTimeZone)
        let time = ClockFormatting.timeComponents(at: viewModel.displayDate(now: now), in: zone, use24Hour: use24Hour)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(selectedEntry?.label ?? "This Mac · \(homeLabel)", systemImage: "mappin")
                    .labelStyle(PillLabelStyle())
                Text(time.main + (time.period.isEmpty ? "" : " " + time.period))
                    .font(.system(size: 13))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textBright)
                Text(TimeWheelView.rulerOffsetLabel(forOffset: viewModel.offset))
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text.opacity(0.74))
                Spacer(minLength: 8)
                Text("Drag, swipe, or ← → · snaps every \(snapMinutes) min")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text.opacity(0.74))
                    .lineLimit(1)
            }
            TimeWheelView(
                anchorNow: now,
                anchorTimeZone: zone,
                use24Hour: use24Hour,
                style: .ruler,
                offset: $viewModel.offset
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 14)
        .litGlass(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onHover { hoveringTimeline = $0 }
    }

    private func deleteButton(_ entry: ClockEntry) -> some View {
        Button(role: .destructive) { viewModel.delete(entry, from: modelContext) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

/// The timeline bar's anchor: a pale-accent pill with a pin.
private struct PillLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 10, weight: .bold))
            configuration.title
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(hex: 0x14121f))
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Capsule().fill(Theme.accentLight))
    }
}

// MARK: - City card

/// A city on the Mac board (canvas Main window card): name, country and offset, where
/// the sun or moon is there, the time, and a Tomorrow/Yesterday tag.
private struct MacCityCard: View {
    let entry: ClockEntry
    let displayDate: Date
    let homeTimeZone: TimeZone
    let use24Hour: Bool
    let showCountryName: Bool
    let flagsDays: Bool
    let isSelected: Bool
    let select: () -> Void
    @State private var hovered = false

    var body: some View {
        let time = ClockFormatting.timeComponents(at: displayDate, in: entry.timeZone, use24Hour: use24Hour)
        let sky = CardSky(hour: ClockFormatting.hourOfDay(in: entry.timeZone, at: displayDate), moonRise: MoonPhase(day: displayDate).rise)
        let day = ClockFormatting.dayOffset(of: entry.timeZone, from: homeTimeZone, at: displayDate)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        Button(action: select) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(entry.label)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.textBright)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundStyle(Theme.text.opacity(0.74))
                            .lineLimit(1)
                            .padding(.top, 3)
                        HStack(spacing: 6) {
                            SkyArc(sky: sky).frame(width: 34, height: 18)
                            Text(sky.label).font(.system(size: 11)).foregroundStyle(Theme.text.opacity(0.72))
                        }
                        .padding(.top, 8)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(sky.label)
                    }
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(time.main)
                                .font(.system(size: 32, weight: .medium))
                                .tracking(-0.64)
                                .foregroundStyle(Theme.textBrightest)
                                .contentTransition(.numericText())
                                .animation(.snappy(duration: 0.35), value: time.main)
                            if !time.period.isEmpty {
                                Text(time.period).font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.78))
                            }
                        }
                        .monospacedDigit()
                        .lifted()
                        if flagsDays && day != 0 {
                            Text(day > 0 ? "Tomorrow" : "Yesterday")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x14121f))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(RoundedRectangle(cornerRadius: 6).fill(day > 0 ? Theme.accentLight : Theme.text))
                        }
                    }
                }
                if isSelected {
                    Rectangle().fill(.white.opacity(0.10)).frame(height: 1).padding(.top, 12)
                    HStack(spacing: 8) {
                        Text("The sky and timeline follow \(entry.label)")
                        Spacer(minLength: 0)
                        Text("Space to release · ⌫ delete")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text.opacity(0.78))
                    .lineLimit(1)
                    .padding(.top, 10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .litGlass(shape)
            .overlay {
                if isSelected {
                    shape.strokeBorder(Theme.accent.opacity(0.95), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .strokeBorder(Theme.accent.opacity(0.25), lineWidth: 3)
                        .padding(-3)
                } else if hovered {
                    shape.strokeBorder(Theme.accentText.opacity(0.35), lineWidth: 1)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var subtitle: String {
        let offset = ClockFormatting.offsetLabel(
            homeOffsetSeconds: homeTimeZone.secondsFromGMT(for: displayDate),
            zoneOffsetSeconds: entry.timeZone.secondsFromGMT(for: displayDate)
        )
        guard showCountryName, let country = entry.country else { return offset }
        return "\(country.flag) \(country.name) · \(offset)"
    }
}

/// The 34×18 sun/moon arc: dotted path, horizon line, and the light as a glowing dot.
private struct SkyArc: View {
    let sky: CardSky

    var body: some View {
        Canvas { context, _ in
            var arc = Path()
            arc.addArc(center: CGPoint(x: 17, y: 16), radius: 14, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            context.stroke(arc, with: .color(Theme.text.opacity(0.28)), style: StrokeStyle(lineWidth: 1, dash: [1.5, 2.5]))
            context.fill(Path(CGRect(x: 1, y: 15.5, width: 32, height: 1)), with: .color(Theme.text.opacity(0.35)))
            let glow = sky.isDay ? Color(hex: 0xf0b48a) : Theme.accent
            let fill = sky.isDay ? Color(hex: 0xf9e7c8) : Color(hex: 0xdcd9f0)
            context.fill(Path(ellipseIn: CGRect(x: sky.x - 5.5, y: sky.y - 5.5, width: 11, height: 11)), with: .color(glow.opacity(0.35)))
            context.fill(Path(ellipseIn: CGRect(x: sky.x - 2.8, y: sky.y - 2.8, width: 5.6, height: 5.6)), with: .color(fill))
        }
    }
}

// MARK: - Menu commands

/// What the menu bar can ask the focused board window to do.
struct BoardActions {
    var addCity: () -> Void
    var now: () -> Void
    var step: (Int) -> Void
    var toggleSidebar: () -> Void
    var findCity: () -> Void
}

private struct BoardActionsKey: FocusedValueKey { typealias Value = BoardActions }

extension FocusedValues {
    var boardActions: BoardActions? {
        get { self[BoardActionsKey.self] }
        set { self[BoardActionsKey.self] = newValue }
    }
}

struct BoardCommands: Commands {
    @FocusedValue(\.boardActions) private var actions
    @AppStorage("use24Hour") private var use24Hour = false

    var body: some Commands {
        // ⌘N adds a city: one board window is the whole app, so "New Window" isn't useful.
        CommandGroup(replacing: .newItem) {
            Button("Add City…") { actions?.addCity() }
                .keyboardShortcut("n")
                .disabled(actions == nil)
        }
        CommandGroup(after: .textEditing) {
            Button("Find City") { actions?.findCity() }
                .keyboardShortcut("f")
                .disabled(actions == nil)
        }
        CommandGroup(before: .sidebar) {
            Button("Toggle Sidebar") { actions?.toggleSidebar() }
                .keyboardShortcut("s", modifiers: [.control, .command])
                .disabled(actions == nil)
            Toggle("24-Hour Time", isOn: $use24Hour)
                .keyboardShortcut("t", modifiers: [.shift, .command])
            Divider()
        }
        CommandMenu("Time") {
            Button("Now") { actions?.now() }
                .keyboardShortcut("0")
            Button("Earlier") { actions?.step(-1) }
                .keyboardShortcut(.leftArrow, modifiers: .option)
            Button("Later") { actions?.step(1) }
                .keyboardShortcut(.rightArrow, modifiers: .option)
        }
    }
}

// MARK: - Menu bar extra

extension Notification.Name {
    /// The menu bar popover's "Add City…": opens the board window, which shows its sheet.
    static let addCityRequested = Notification.Name("WorldClock.addCityRequested")
}

/// The menu bar popover (canvas MenuBar board): the home sky and time, every city, a
/// peek-ahead ruler that shifts every time shown here, and the app's three entry points.
struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @Query(sort: \ClockEntry.sortOrder) private var entries: [ClockEntry]
    @AppStorage("use24Hour") private var use24Hour = false
    @AppStorage("snapMinutes") private var snapMinutes = 15
    @AppStorage("homeTimeZoneIdentifier") private var homeTimeZoneIdentifier = ""
    @AppStorage("homeTimeZoneLabel") private var homeTimeZoneLabel = ""
    @State private var peek: TimeInterval = 0
    @State private var peekStart: TimeInterval?

    /// The peek ruler's scale: one tick per snap step, 10 pt apart.
    private var pointsPerMinute: Double { 10 / Double(snapMinutes) }

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let shown = timeline.date.addingTimeInterval(peek)
            let home = ClockFormatting.homeZone(homeTimeZoneIdentifier)
            let homeTime = ClockFormatting.timeComponents(at: shown, in: home, use24Hour: use24Hour)
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    BackgroundView(hour: ClockFormatting.hourOfDay(in: home, at: shown))
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Home · \(ClockFormatting.homeLabel(identifier: homeTimeZoneIdentifier, label: homeTimeZoneLabel))")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(0.88)
                            .textCase(.uppercase)
                            .foregroundStyle(Theme.accentLight)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(homeTime.main).font(.system(size: 34, weight: .medium))
                            if !homeTime.period.isEmpty {
                                Text(homeTime.period).font(.system(size: 14)).opacity(0.8)
                            }
                        }
                        .monospacedDigit()
                        .foregroundStyle(Theme.textBrightest)
                        Text(shown.formatted(Date.FormatStyle(timeZone: home).weekday(.wide).month(.wide).day()))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textBright.opacity(0.8))
                    }
                    .shadow(color: Color(hex: 0x090b18).opacity(0.6), radius: 5, y: 1)
                    .padding(.leading, 16)
                    .padding(.top, 14)
                }
                .frame(height: 118)
                .clipped()

                VStack(spacing: 1) {
                    ForEach(entries) { entry in
                        cityRow(entry, at: shown, home: home)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 6)

                peekRuler
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                    .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.10)).frame(height: 1) }
                    .padding(.horizontal, 12)

                VStack(spacing: 1) {
                    MenuItem(title: "Open World Clock", shortcut: "⌘O") { openBoard() }
                        .keyboardShortcut("o")
                    MenuItem(title: "Add City…", shortcut: "⌘N") {
                        openBoard()
                        NotificationCenter.default.post(name: .addCityRequested, object: nil)
                    }
                    .keyboardShortcut("n")
                    SettingsLink { MenuItemLabel(title: "Settings…", shortcut: "⌘,") }
                        .buttonStyle(.plain)
                        .keyboardShortcut(",")
                }
                .padding(6)
                .overlay(alignment: .top) { Rectangle().fill(.white.opacity(0.10)).frame(height: 1) }
            }
            .frame(width: 340)
            .background(Theme.glass.opacity(0.62))
            .environment(\.colorScheme, .dark)
        }
    }

    private func openBoard() {
        openWindow(id: "board")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func cityRow(_ entry: ClockEntry, at date: Date, home: TimeZone) -> some View {
        let time = ClockFormatting.timeComponents(at: date, in: entry.timeZone, use24Hour: use24Hour)
        let offset = ClockFormatting.offsetLabel(homeOffsetSeconds: home.secondsFromGMT(for: date), zoneOffsetSeconds: entry.timeZone.secondsFromGMT(for: date))
        let day = ClockFormatting.dayOffset(of: entry.timeZone, from: home, at: date)
        return HoverRow {
            Text(entry.country?.flag ?? "").frame(width: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(entry.label).font(.system(size: 13))
                Text(offset + (day > 0 ? " · Tomorrow" : day < 0 ? " · Yesterday" : ""))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(Theme.text.opacity(0.68))
            }
            Spacer(minLength: 8)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(time.main).font(.system(size: 17, weight: .medium)).foregroundStyle(Theme.textBrightest)
                if !time.period.isEmpty {
                    Text(time.period).font(.system(size: 11)).opacity(0.75)
                }
            }
            .monospacedDigit()
        }
    }

    /// Drag to look ahead (or back) without opening the window; it snaps like the
    /// board's wheel, and ← → step it when the popover has focus.
    private var peekRuler: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Peek ahead")
                Spacer()
                Text(TimeWheelView.rulerOffsetLabel(forOffset: peek)).monospacedDigit()
            }
            .font(.system(size: 11))
            .foregroundStyle(Theme.text.opacity(0.7))

            Canvas { context, size in
                let shift = (peek / 60 * pointsPerMinute).truncatingRemainder(dividingBy: 10)
                var x = (size.width / 2 - shift).truncatingRemainder(dividingBy: 10)
                while x < size.width {
                    let fade = min(1, max(0, min(x, size.width - x) / (size.width * 0.2)))
                    context.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Theme.accentLight.opacity(0.6 * fade)))
                    x += 10
                }
                context.drawLayer { ctx in
                    ctx.addFilter(.shadow(color: Theme.accent, radius: 4))
                    ctx.fill(Path(CGRect(x: size.width / 2 - 1, y: 2, width: 2, height: size.height - 4)), with: .color(Theme.accent))
                }
            }
            .frame(height: 26)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x10121e).opacity(0.5)))
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if peekStart == nil { peekStart = peek }
                    peek = clampPeek((peekStart ?? 0) - Double(value.translation.width) / pointsPerMinute * 60)
                }
                .onEnded { _ in
                    peekStart = nil
                    let snap = Double(snapMinutes) * 60
                    withAnimation(.easeOut(duration: 0.3)) { peek = clampPeek((peek / snap).rounded() * snap) }
                })
            .accessibilityElement()
            .accessibilityLabel("Peek ahead")
            .accessibilityValue(TimeWheelView.rulerOffsetLabel(forOffset: peek))
            .accessibilityAdjustableAction { direction in
                let step = Double(snapMinutes) * 60
                peek = clampPeek(peek + (direction == .increment ? step : -step))
            }
        }
    }

    private func clampPeek(_ value: TimeInterval) -> TimeInterval { min(max(value, -48 * 3600), 48 * 3600) }
}

private struct MenuItemLabel: View {
    let title: String
    let shortcut: String
    var body: some View {
        HoverRow {
            Text(title).font(.system(size: 13))
            Spacer()
            Text(shortcut).font(.system(size: 12)).foregroundStyle(Theme.text.opacity(0.6))
        }
    }
}

private struct MenuItem: View {
    let title: String
    let shortcut: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { MenuItemLabel(title: title, shortcut: shortcut) }
            .buttonStyle(.plain)
    }
}

/// A popover row: accent highlight under the pointer, like a menu.
private struct HoverRow<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var hovered = false
    var body: some View {
        HStack(spacing: 10) { content }
            .foregroundStyle(hovered ? Theme.textBrightest : Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(hovered ? Theme.accent.opacity(0.32) : .clear))
            .contentShape(Rectangle())
            .onHover { hovered = $0 }
    }
}
#endif
