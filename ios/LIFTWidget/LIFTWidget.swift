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

struct LIFTWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: LiftEntry

    private var current: WorkoutExercise? {
        guard let s = entry.snapshot, s.currentIndex >= 0, s.currentIndex < s.exercises.count else { return nil }
        return s.exercises[s.currentIndex]
    }

    private var header: String {
        guard let s = entry.snapshot else { return "LIFT" }
        return "\(s.day) · \(s.week)-Week"
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
        default:
            small
        }
    }

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
}

struct LIFTWidget: Widget {
    let kind = "LIFTWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LiftProvider()) { entry in
            LIFTWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("LIFT — Today")
        .description("Your current exercise, advancing as you log.")
        .supportedFamilies([.accessoryInline, .accessoryRectangular, .systemSmall])
    }
}
