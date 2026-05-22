import Foundation
import SwiftData

@Model
final class TransactionRecord {
    var id: UUID
    var date: Date
    var ticker: String
    var action: String
    var detail: String

    init(
        id: UUID = UUID(),
        date: Date = Date.now,
        ticker: String = "",
        action: String = "",
        detail: String = ""
    ) {
        self.id = id
        self.date = date
        self.ticker = ticker
        self.action = action
        self.detail = detail
    }
}
