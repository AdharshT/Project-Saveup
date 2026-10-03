import Foundation

func effectiveIncomeAmount(_ income: Income) -> Double {
    if income.payType == .hourly {
        return income.amount * (income.hoursPerPeriod ?? 0)
    }
    return income.amount
}
