import Foundation

struct TimeSlot: Identifiable, Codable, Hashable {
    let id: Int
    var start: String
    var end: String
}

struct DaySchedule: Identifiable, Codable, Hashable {
    let id: Int
    let name: String
    var morning: TimeSlot
    var afternoon: TimeSlot
}

struct ESPStatus {
    var time = "--:--:--"
    var ledOn = false
    var wifiOn = true
}
