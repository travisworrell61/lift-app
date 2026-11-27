import WidgetKit
import SwiftUI

struct LiftEntry: TimelineEntry {
    let date: Date
    let snapshot: WorkoutSnapshot?
}

struct LiftProvider: TimelineProvider {
    func placeholder(in context: Context) -> LiftEntry {
        LiftEntry(date: Date(), snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (LiftEntry) -> Void) {
        completion(LiftEntry(date: Date(), snapshot: LiftStore.load()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LiftEntry>) -> Void) {
        // Single entry; the app pushes refreshes via WidgetCenter when state changes.
        let entry = LiftEntry(date: Date(), snapshot: LiftStore.load())
        completion(Timeline(entries: [entry], policy: .never))
    }
}

private let liftAccentFallback = Color(red: 0.49, green: 0.83, blue: 0.99)   // sky

// App theme tokens (index.html :root) — graphite surfaces, one lime accent.
enum Theme {
    static let bg    = Color(red: 0x07/255, green: 0x08/255, blue: 0x0a/255)   // #07080a
    static let s1    = Color(red: 0x11/255, green: 0x13/255, blue: 0x17/255)   // #111317
    static let ink   = Color(red: 0xf5/255, green: 0xf6/255, blue: 0xf8/255)   // #f5f6f8
    static let steel = Color(red: 0xc3/255, green: 0xc8/255, blue: 0xd2/255)   // #c3c8d2
    static let muted = Color(red: 0x8c/255, green: 0x93/255, blue: 0xa1/255)   // #8c93a1
    static let lime  = Color(red: 0xc8/255, green: 0xf1/255, blue: 0x35/255)   // #c8f135
}

extension Color {
    init?(hex: String?) {
        guard var h = hex else { return nil }
        h = h.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard h.count == 6, let v = Int(h, radix: 16) else { return nil }
        self = Color(red: Double((v >> 16) & 0xFF)/255,
                     green: Double((v >> 8) & 0xFF)/255,
                     blue: Double(v & 0xFF)/255)
    }
}

struct LIFTWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: LiftEntry

    private var liftAccent: Color { Color(hex: entry.snapshot?.accent) ?? liftAccentFallback }

    private var current: WorkoutExercise? {
        guard let s = entry.snapshot, s.currentIndex >= 0, s.currentIndex < s.exercises.count else { return nil }
        return s.exercises[s.currentIndex]
    }

    private var header: String {
        guard let s = entry.snapshot else { return "LIFT" }
        return s.day   // single weekly program — the old "A-Week" suffix is retired
    }

    private var inlineText: String {
        guard let s = entry.snapshot else { return "LIFT" }
        if let c = current { return "\(s.day): \(c.name)" }
        return "\(s.day): done ✓"
    }

    @Environment(\.colorScheme) private var scheme
    private var isLock: Bool { family == .accessoryInline || family == .accessoryRectangular || family == .accessoryCircular }

    var body: some View {
        content
          // Home Screen sizes always draw on graphite, so keep text in dark-mode colors even in Light Mode.
          .environment(\.colorScheme, isLock ? scheme : .dark)
          .containerBackground(for: .widget) {
            switch family {
            case .accessoryInline, .accessoryRectangular, .accessoryCircular:
                Color.clear    // Lock Screen: the system draws its own material
            default:
                LinearGradient(colors: [Theme.s1, Theme.bg], startPoint: .top, endPoint: .bottom)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            rectangular
        case .accessoryCircular:
            circular
        case .systemMedium:
            listView(max: 4, compact: true)
        case .systemLarge:
            listView(max: 7, compact: false)
        default:
            small
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(header).font(.caption2).foregroundStyle(.secondary)
            if let s = entry.snapshot, let c = current {
                Text(c.name).font(.headline).lineLimit(2).widgetAccentable()
                Text("\(c.reps) · \(s.currentIndex + 1)/\(s.total)")
                    .font(.caption2).foregroundStyle(.secondary)
            } else if entry.snapshot != nil {
                Text("Workout complete ✓").font(.headline)
            } else {
                Text("Open LIFT & pick a day").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // Small round Lock Screen widget: a ring that fills as you log, with today's count in the middle.
    @ViewBuilder private var circular: some View {
        if let s = entry.snapshot, s.total > 0 {
            let done = Swift.min(s.doneCount, s.total)
            Gauge(value: Double(done), in: 0...Double(s.total)) {
                Image(systemName: "dumbbell.fill")
            } currentValueLabel: {
                if done >= s.total {
                    Image(systemName: "checkmark").font(.system(size: 18, weight: .bold))
                } else {
                    VStack(spacing: -2) {
                        Text("\(done)").font(.system(size: 17, weight: .bold, design: .rounded)).monospacedDigit()
                        Text(s.day.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(0.5)
                    }
                }
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .widgetAccentable()
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "dumbbell.fill").font(.system(size: 20, weight: .semibold))
            }
        }
    }

    // MARK: - Home Screen small

    // Graphite + lime, matching the app's theme. Tapping anywhere opens LIFT (widget default).
    @ViewBuilder private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("LIFT").font(.system(size: 13, weight: .heavy)).tracking(2.2)
                    .foregroundStyle(Theme.lime).widgetAccentable()
                Spacer(minLength: 4)
                if let s = entry.snapshot {
                    Text(s.day.uppercased()).font(.system(size: 11, weight: .semibold)).tracking(1.2)
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 6)
            if let s = entry.snapshot, let c = current {
                Text("UP NEXT").font(.system(size: 9, weight: .bold)).tracking(1.4).foregroundStyle(Theme.muted)
                Text(c.name).font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                    .lineLimit(3).minimumScaleFactor(0.8).padding(.top, 2)
                Text(c.reps).font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.steel)
                    .lineLimit(1).padding(.top, 2)
                Spacer(minLength: 6)
                progress(done: s.doneCount, total: s.total)
            } else if let s = entry.snapshot {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Theme.lime).widgetAccentable()
                Text("Workout done").font(.system(size: 16, weight: .bold)).foregroundStyle(Theme.ink).padding(.top, 4)
                Spacer(minLength: 6)
                progress(done: s.doneCount, total: s.total)
            } else {
                Text("Tap to start").font(.system(size: 17, weight: .bold)).foregroundStyle(Theme.ink)
                Text("Pick today's workout").font(.system(size: 12)).foregroundStyle(Theme.steel).padding(.top, 2)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    @ViewBuilder private func progress(done: Int, total: Int) -> some View {
        let f = total > 0 ? Swift.min(1, Double(done) / Double(total)) : 0
        HStack(spacing: 8) {
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Theme.lime).frame(width: Swift.max(f > 0 ? 5 : 0, g.size.width * f))
                        .widgetAccentable()
                }
            }
            .frame(height: 5)
            Text("\(done)/\(total)").font(.system(size: 11, weight: .bold).monospacedDigit())
                .foregroundStyle(Theme.steel)
        }
    }

    // MARK: - Home Screen medium / large (the "see what's coming" list)

    // Pick a window of exercises that always keeps the current one visible.
    private func window(_ s: WorkoutSnapshot, max: Int) -> Range<Int> {
        let count = s.exercises.count
        if count <= max { return 0..<count }
        let start = Swift.min(Swift.max(0, s.currentIndex), count - max)
        return start..<(start + max)
    }

    @ViewBuilder private func listView(max: Int, compact: Bool) -> some View {
        if let s = entry.snapshot, !s.exercises.isEmpty {
            VStack(alignment: .leading, spacing: compact ? 5 : 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    RoundedRectangle(cornerRadius: 2).fill(liftAccent)
                        .frame(width: compact ? 4 : 5, height: compact ? 16 : 22)
                    Text(s.title).font(compact ? .headline : .largeTitle).bold().lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(s.doneCount)/\(s.total)")
                        .font(compact ? .caption : .title3).bold()
                        .foregroundStyle(liftAccent)
                }
                if !compact {
                    Text(s.sub).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
                let range = window(s, max: max)
                VStack(alignment: .leading, spacing: compact ? 4 : 9) {
                    ForEach(range, id: \.self) { i in
                        row(s.exercises[i], index: i, current: s.currentIndex, done: s.isDone(i),
                            prevGrp: i > 0 ? s.exercises[i - 1].grp : nil, compact: compact)
                    }
                }
                if !compact { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            VStack(spacing: 6) {
                Text("LIFT").font(.headline)
                Text("Open the app and pick a day").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func row(_ ex: WorkoutExercise, index: Int, current: Int, done: Bool, prevGrp: Int?, compact: Bool) -> some View {
        let isCurrent = index == current
        let isDone = done
        let inSS = ex.ss ?? false
        let startsSS = inSS && ex.grp != prevGrp   // first row of a superset group
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(inSS ? liftAccent : Color.secondary.opacity(0.25))
                .frame(width: 3)
                .frame(maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 1) {
                if startsSS {
                    Text("SUPERSET").font(.system(size: 8, weight: .bold))
                        .foregroundStyle(liftAccent).tracking(0.5)
                }
                Text(ex.name)
                    .font(compact ? .caption : .headline)
                    .fontWeight(isCurrent ? .bold : .regular)
                    .foregroundStyle(isCurrent ? liftAccent : (isDone ? .secondary : .primary))
                    .strikethrough(isDone, color: .secondary)
                    .lineLimit(1)
                if !compact {
                    Text(ex.reps).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if isDone {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else if isCurrent {
                Text("NOW").font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(liftAccent))
            } else if compact {
                Text(ex.reps).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct LIFTWidget: Widget {
    let kind = "LIFTWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LiftProvider()) { entry in
            LIFTWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("LIFT — Today")
        .description("Your workout, advancing as you log. Use a large size to see what's coming.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .accessoryCircular,
                            .systemSmall, .systemMedium, .systemLarge])
    }
}
