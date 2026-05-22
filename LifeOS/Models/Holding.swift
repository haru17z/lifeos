import Foundation
import SwiftData

@Model
final class Holding {
    var id: UUID
    var ticker: String
    var name: String
    var amountInvested: Double
    var currentValue: Double
    var dailyChange: Double
    var dailyChangePercent: Double
    var currentDailyPrice: Double
    var previousClose: Double
    var sharesOwned: Double

    init(
        id: UUID = UUID(),
        ticker: String = "",
        name: String = "",
        amountInvested: Double = 0,
        currentValue: Double = 0,
        dailyChange: Double = 0,
        dailyChangePercent: Double = 0,
        currentDailyPrice: Double = 0,
        previousClose: Double = 0,
        sharesOwned: Double = 0
    ) {
        self.id = id
        self.ticker = ticker
        self.name = name
        self.amountInvested = amountInvested
        self.currentValue = currentValue
        self.dailyChange = dailyChange
        self.dailyChangePercent = dailyChangePercent
        self.currentDailyPrice = currentDailyPrice
        self.previousClose = previousClose
        self.sharesOwned = sharesOwned
    }

    var absolutePnL: Double {
        let pnl = currentValue - amountInvested
        guard !pnl.isNaN, !pnl.isInfinite else { return 0 }
        return pnl
    }

    var pnlPercent: Double {
        guard amountInvested > 0 else { return 0 }
        let pct = (absolutePnL / amountInvested) * 100
        guard !pct.isNaN, !pct.isInfinite else { return 0 }
        return pct
    }

    var safeCurrentValue: Double {
        guard !currentValue.isNaN, !currentValue.isInfinite else { return 0 }
        return currentValue
    }

    var safeAmountInvested: Double {
        guard !amountInvested.isNaN, !amountInvested.isInfinite else { return 0 }
        return amountInvested
    }

    var safeDailyChange: Double {
        guard !dailyChange.isNaN, !dailyChange.isInfinite else { return 0 }
        return dailyChange
    }

    var safeDailyChangePercent: Double {
        guard !dailyChangePercent.isNaN, !dailyChangePercent.isInfinite else { return 0 }
        return dailyChangePercent
    }

    /// Applies a mock daily price update. In production, this will be replaced with a real API call.
    func updateDailyPrice(to newPrice: Double) {
        guard !newPrice.isNaN, !newPrice.isInfinite, newPrice > 0 else { return }
        previousClose = currentDailyPrice > 0 ? currentDailyPrice : newPrice
        currentDailyPrice = newPrice

        if sharesOwned <= 0 && currentDailyPrice > 0 {
            sharesOwned = amountInvested / previousClose
        }

        let newValue = sharesOwned * currentDailyPrice
        guard !newValue.isNaN, !newValue.isInfinite else { return }

        let oldValue = currentValue
        currentValue = newValue
        dailyChange = newValue - oldValue

        if oldValue > 0 {
            let pct = ((newValue - oldValue) / oldValue) * 100
            dailyChangePercent = pct.isNaN || pct.isInfinite ? 0 : pct
        } else {
            dailyChangePercent = 0
        }
    }

    /// Recalculates the position value based on amount invested. Call when updating amountInvested.
    func recalculatePosition() {
        guard !amountInvested.isNaN, !amountInvested.isInfinite else { return }
        if currentDailyPrice > 0 && !currentDailyPrice.isNaN && !currentDailyPrice.isInfinite {
            sharesOwned = amountInvested / currentDailyPrice
            let newValue = sharesOwned * currentDailyPrice
            if !newValue.isNaN, !newValue.isInfinite {
                currentValue = newValue
            }
        } else {
            currentValue = amountInvested
        }
    }
}
