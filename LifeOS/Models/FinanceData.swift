import Foundation
import SwiftData

@Model
final class FinanceData {
    var dailyDCAAmount: Double
    var nasdaq100Allocation: Double
    var sp500Allocation: Double
    var btcAllocation: Double
    var cashAllocation: Double

    init(
        dailyDCAAmount: Double = 0,
        nasdaq100Allocation: Double = 30,
        sp500Allocation: Double = 40,
        btcAllocation: Double = 20,
        cashAllocation: Double = 10
    ) {
        self.dailyDCAAmount = dailyDCAAmount
        self.nasdaq100Allocation = nasdaq100Allocation
        self.sp500Allocation = sp500Allocation
        self.btcAllocation = btcAllocation
        self.cashAllocation = cashAllocation
    }
}
