import Foundation

struct Note: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var content: String
    let createdAt: Double
    var updatedAt: Double
}
