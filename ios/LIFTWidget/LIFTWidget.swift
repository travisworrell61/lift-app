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

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(inlineText)
        case .accessoryRectangular:
            rectangular
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

    // MARK: - Home Screen small

    @ViewBuilder private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(header).font(.caption2).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            if let s = entry.snapshot, let c = current {
                Text(c.name).font(.system(.headline, design: .rounded)).bold().lineLimit(3)
                Text(c.reps).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("\(s.currentIndex + 1) / \(s.total)").font(.caption2).foregroundStyle(.secondary)
            } else if entry.snapshot != nil {
                Text("Done ✓").font(.title3).bold()
            } else {
                Text("Pick a day in LIFT").font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("LIFT — Today")
        .description("Your workout, advancing as you log. Use a large size to see what's coming.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular,
                            .systemSmall, .systemMedium, .systemLarge])
    }
}
