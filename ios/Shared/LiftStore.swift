import Foundation

// Shared between the app (writes) and the widget (reads) via an App Group.
struct WorkoutExercise: Codable {
    var name: String
    var reps: String
}

struct WorkoutSnapshot: Codable {
    var day: String          // short label, e.g. "TUE"
    var title: String        // e.g. "Tuesday"
    var sub: String          // muscles line
    var week: String         // "A" / "B"
    var exercises: [WorkoutExercise]
    var currentIndex: Int    // first exercise not yet logged today
    var total: Int
    var updated: Date?
}

enum LiftStore {
    static let suiteName = "group.com.travisworrell61.lift"
    static let key = "snapshot"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: suiteName) }

    static func save(_ snapshot: WorkoutSnapshot) {
        guard let d = defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        d.set(data, forKey: key)
    }

    static func load() -> WorkoutSnapshot? {
        guard let d = defaults, let data = d.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WorkoutSnapshot.self, from: data)
    }
}
