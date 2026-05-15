import SwiftUI
import SwiftData
import Charts

// MARK: - FinanceView

struct FinanceView: View {

    @Query private var financeData: [FinanceData]
    @Environment(\.modelContext) private var modelContext

    @State private var dcaAmount: Double = 0
    @State private var nasdaqAlloc: Double = 30
    @State private var sp500Alloc: Double = 40
    @State private var btcAlloc: Double = 20
    @State private var cashAlloc: Double = 10

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    assetAllocationPie
                    dcaSection
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle(L10n.finance)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: loadData)
        }
    }

    // MARK: Asset Allocation Pie Chart

    private var assetAllocationPie: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.assetAllocation)
                .font(.headline)

            let allocations: [(String, Double, Color)] = [
                (L10n.nasdaq100, nasdaqAlloc, .blue),
                (L10n.sp500, sp500Alloc, .green),
                (L10n.btc, btcAlloc, .orange),
                (L10n.cash, cashAlloc, .gray)
            ]

            Chart {
                ForEach(allocations, id: \.0) { (label, value, color) in
                    SectorMark(
                        angle: .value("Allocation", value),
                        innerRadius: .ratio(0.5),
                        angularInset: 1
                    )
                    .foregroundStyle(color.gradient)
                    .annotation(position: .overlay) {
                        if value > 5 {
                            Text("\(Int(value))%")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .frame(height: 250)

            // Legend
            VStack(spacing: 8) {
                ForEach(allocations, id: \.0) { (label, value, color) in
                    HStack {
                        Circle()
                            .fill(color)
                            .frame(width: 10, height: 10)
                        Text(label)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(value))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
            }
            .padding(.top, 8)

            // Edit sliders
            VStack(spacing: 12) {
                allocationSlider(label: L10n.nasdaq100, value: $nasdaqAlloc, color: .blue)
                allocationSlider(label: L10n.sp500, value: $sp500Alloc, color: .green)
                allocationSlider(label: L10n.btc, value: $btcAlloc, color: .orange)
                allocationSlider(label: L10n.cash, value: $cashAlloc, color: .gray)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func allocationSlider(label: String, value: Binding<Double>, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            Slider(value: value, in: 0...100, step: 1)
                .tint(color)
                .onChange(of: value.wrappedValue) { _, _ in saveData() }
        }
    }

    // MARK: DCA Section

    private var dcaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.dailyDCALabel)
                .font(.headline)

            HStack(spacing: 12) {
                Text("$")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                TextField("0.00", value: $dcaAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(L10n.dcaFootnote)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onChange(of: dcaAmount) { _, _ in saveData() }
    }

    // MARK: Data Persistence

    private func loadData() {
        if let existing = financeData.first {
            dcaAmount = existing.dailyDCAAmount
            nasdaqAlloc = existing.nasdaq100Allocation
            sp500Alloc = existing.sp500Allocation
            btcAlloc = existing.btcAllocation
            cashAlloc = existing.cashAllocation
        }
    }

    private func saveData() {
        if let existing = financeData.first {
            existing.dailyDCAAmount = dcaAmount
            existing.nasdaq100Allocation = nasdaqAlloc
            existing.sp500Allocation = sp500Alloc
            existing.btcAllocation = btcAlloc
            existing.cashAllocation = cashAlloc
        } else {
            let new = FinanceData(
                dailyDCAAmount: dcaAmount,
                nasdaq100Allocation: nasdaqAlloc,
                sp500Allocation: sp500Alloc,
                btcAllocation: btcAlloc,
                cashAllocation: cashAlloc
            )
            modelContext.insert(new)
        }
    }
}
