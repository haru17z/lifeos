import SwiftUI
import SwiftData
import Charts

// MARK: - FinanceView

struct FinanceView: View {

    @Query private var holdings: [Holding]
    @Query private var financeData: [FinanceData]
    @Query(sort: \TransactionRecord.date, order: .reverse) private var transactions: [TransactionRecord]
    @Environment(\.modelContext) private var modelContext
    @Environment(IntentRouter.self) private var router

    // NLP Chatbox
    @FocusState private var isChatFocused: Bool
    @State private var chatInput: String = ""
    @State private var isProcessingCommand = false
    @State private var chatMessage: String?

    // Add holding form
    @State private var showAddForm = false
    @State private var newTicker: String = ""
    @State private var newName: String = ""
    @State private var newAmountInvested: Double = 0
    @State private var newCurrentValue: Double = 0
    @State private var newDailyChange: Double = 0
    @State private var newDailyChangePercent: Double = 0

    // DCA
    @State private var dcaAmount: Double = 0

    // Ticker lookup
    @State private var tickerSuggestions: [String] = []

    // Daily price update
    @AppStorage("LastFinanceUpdateDate") private var lastUpdateDate: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    nlpChatbox
                    portfolioSection
                    analyticsSection
                    transactionHistorySection
                    dcaSection
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .contentShape(Rectangle())
            .onTapGesture { isChatFocused = false }
            .navigationTitle(L10n.finance)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadDCA()
                performDailyPriceUpdateIfNeeded()
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: holdings.count)
        }
    }

    // MARK: NLP Chatbox

    private var nlpChatbox: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "message.and.waveform")
                    .foregroundStyle(.orange)
                Text(L10n.financeChat)
                    .font(.headline)
                Spacer()
                if isProcessingCommand {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.orange)
                }
            }

            HStack(spacing: 10) {
                TextField(L10n.financeChatPlaceholder, text: $chatInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .focused($isChatFocused)
                    .lineLimit(1...3)
                    .onSubmit { submitFinanceCommand() }

                Button(action: submitFinanceCommand) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            chatInput.trimmingCharacters(in: .whitespaces).isEmpty || isProcessingCommand
                                ? Color(.tertiaryLabel)
                                : Color.orange
                        )
                }
                .disabled(chatInput.trimmingCharacters(in: .whitespaces).isEmpty || isProcessingCommand)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let msg = chatMessage {
                HStack {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            chatMessage = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                }
                .padding(10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func submitFinanceCommand() {
        let text = chatInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        isProcessingCommand = true
        chatMessage = nil
        isChatFocused = false

        Task {
            do {
                let msg = try await router.processFinanceCommand(
                    input: text,
                    modelContext: modelContext,
                    holdings: holdings
                )
                await MainActor.run {
                    chatMessage = msg
                    chatInput = ""
                }
            } catch {
                await MainActor.run {
                    chatMessage = "AI unavailable — use the form below to manage holdings."
                }
            }
            await MainActor.run {
                isProcessingCommand = false
            }
        }
    }

    // MARK: Portfolio Section

    private var portfolioSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.orange)
                Text(L10n.portfolio)
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showAddForm.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showAddForm ? "xmark.circle.fill" : "plus.circle.fill")
                            .font(.title3)
                        Text(showAddForm ? L10n.close : L10n.addHolding)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.orange)
                }
            }

            if showAddForm {
                addHoldingForm
            }

            if !holdings.isEmpty {
                // Compact allocation bar
                allocationBar

                // Portfolio list
                VStack(spacing: 0) {
                    ForEach(Array(holdings.enumerated()), id: \.element.id) { idx, holding in
                        portfolioRow(holding)
                        if idx < holdings.count - 1 {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(L10n.noHoldings)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(L10n.tapToAdd)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: Compact Allocation Bar

    private var allocationBar: some View {
        let total = holdings.reduce(0) { $0 + $1.safeCurrentValue }
        guard total > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(holdings) { holding in
                            let proportion = holding.safeCurrentValue / total
                            if proportion > 0 {
                                Rectangle()
                                    .fill(colorForHolding(holding))
                                    .frame(width: max(geo.size.width * CGFloat(proportion), 4), height: 8)
                            }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 8)

                // Legend dots
                HStack(spacing: 16) {
                    ForEach(holdings) { holding in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(colorForHolding(holding))
                                .frame(width: 6, height: 6)
                            Text(holding.ticker.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        )
    }

    private func portfolioRow(_ holding: Holding) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(colorForHolding(holding))
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(holding.ticker.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(holding.name)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("$\(String(format: "%.0f", holding.safeCurrentValue))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                HStack(spacing: 2) {
                    Image(systemName: holding.safeDailyChange >= 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 7))
                    Text("$\(String(format: "%.2f", abs(holding.safeDailyChange)))")
                }
                .font(.caption2)
                .foregroundStyle(holding.safeDailyChange >= 0 ? .green : .red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func colorForHolding(_ holding: Holding) -> Color {
        let colors: [Color] = [.orange, .blue, .green, .purple, .pink, .teal, .indigo, .yellow]
        if let idx = holdings.firstIndex(where: { $0.id == holding.id }) {
            return colors[idx % colors.count]
        }
        return .orange
    }

    // MARK: Add Holding Form

    private var addHoldingForm: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                TextField(L10n.tickerPlaceholder, text: $newTicker)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .frame(maxWidth: 100)
                    .autocapitalization(.allCharacters)
                    .onChange(of: newTicker) { _, ticker in
                        autoFillName(from: ticker)
                    }

                TextField(L10n.namePlaceholder, text: $newName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if !tickerSuggestions.isEmpty && !newTicker.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Text(L10n.fuzzyMatch + ":")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        ForEach(tickerSuggestions, id: \.self) { suggestion in
                            Button {
                                newTicker = suggestion
                                autoFillName(from: suggestion)
                                tickerSuggestions = []
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.orange.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.amountInvested)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", value: $newAmountInvested, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.currentValueLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    HStack {
                        Text("$")
                            .foregroundStyle(.secondary)
                        TextField("0", value: $newCurrentValue, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    .font(.subheadline)
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Button {
                upsertHoldingFromForm()
            } label: {
                Text("Save Holding")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .disabled(newTicker.trimmingCharacters(in: .whitespaces).isEmpty || newAmountInvested <= 0)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Fuzzy Ticker Lookup

    private func autoFillName(from input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespaces).uppercased()
        guard trimmed.count >= 1 else {
            tickerSuggestions = []
            return
        }

        let allTickers = tickerDatabase.keys.sorted()
        let matches = allTickers.filter { ticker in
            ticker.hasPrefix(trimmed) || ticker.contains(trimmed)
        }
        tickerSuggestions = Array(matches.prefix(5))

        if let exactName = tickerDatabase[trimmed] {
            if newName.isEmpty || newName == newTicker {
                newName = exactName
            }
        }
    }

    // MARK: Analytics Dashboard

    private var analyticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "tablecells.fill")
                    .foregroundStyle(.orange)
                Text(L10n.analyticsDashboard)
                    .font(.headline)
            }

            if holdings.isEmpty {
                HStack {
                    Spacer()
                    Text("Add holdings to see analytics")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                analyticsHeader

                Divider()

                ForEach(holdings) { holding in
                    analyticsRow(holding)
                }

                Divider()
                    .overlay(.orange.opacity(0.5))

                analyticsSummary
                    .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var analyticsHeader: some View {
        HStack(spacing: 0) {
            Text("Ticker")
                .frame(width: 55, alignment: .leading)
            Text("Invested")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Value")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("Δ Day")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("PnL")
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("PnL%")
                .frame(width: 48, alignment: .trailing)
        }
        .font(.caption2)
        .fontWeight(.semibold)
        .foregroundStyle(.tertiary)
    }

    private func analyticsRow(_ holding: Holding) -> some View {
        HStack(spacing: 0) {
            Text(holding.ticker.uppercased())
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.orange)
                .frame(width: 55, alignment: .leading)

            Text("$\(String(format: "%.0f", holding.safeAmountInvested))")
                .font(.caption)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            Text("$\(String(format: "%.0f", holding.safeCurrentValue))")
                .font(.caption)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            HStack(spacing: 2) {
                Image(systemName: holding.safeDailyChange >= 0 ? "arrow.up" : "arrow.down")
                    .font(.system(size: 8))
                Text("$\(String(format: "%.2f", abs(holding.safeDailyChange)))")
            }
            .font(.caption2)
            .foregroundStyle(holding.safeDailyChange >= 0 ? .green : .red)
            .frame(maxWidth: .infinity, alignment: .trailing)

            let pnl = holding.absolutePnL
            Text("$\(String(format: "%.2f", pnl))")
                .font(.caption)
                .foregroundStyle(pnl >= 0 ? .green : .red)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)

            let pnlPct = holding.pnlPercent
            Text("\(String(format: "%+.1f", pnlPct))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(pnlPct >= 0 ? .green : .red)
                .monospacedDigit()
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.vertical, 6)
    }

    private var analyticsSummary: some View {
        let totalInvested = holdings.reduce(0) { $0 + $1.safeAmountInvested }
        let totalValue = holdings.reduce(0) { $0 + $1.safeCurrentValue }
        let totalDailyChange = holdings.reduce(0) { $0 + $1.safeDailyChange }
        let totalPnL = totalValue - totalInvested
        let totalPnLPercent: Double = {
            guard totalInvested > 0 else { return 0 }
            let pct = (totalPnL / totalInvested) * 100
            guard !pct.isNaN, !pct.isInfinite else { return 0 }
            return pct
        }()

        return VStack(spacing: 6) {
            HStack(spacing: 0) {
                Text("TOTAL")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundStyle(.primary)
                    .frame(width: 55, alignment: .leading)

                Text("$\(String(format: "%.0f", totalInvested))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("$\(String(format: "%.0f", totalValue))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("$\(String(format: "%.2f", totalDailyChange))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(totalDailyChange >= 0 ? .green : .red)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("$\(String(format: "%.2f", totalPnL))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(totalPnL >= 0 ? .green : .red)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("\(String(format: "%+.1f", totalPnLPercent))%")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundStyle(totalPnLPercent >= 0 ? .green : .red)
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    // MARK: Transaction History

    private var transactionHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "list.bullet.rectangle")
                    .foregroundStyle(.orange)
                Text(L10n.transactionHistory)
                    .font(.headline)
                Spacer()
                Text("\(transactions.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            if transactions.isEmpty {
                HStack {
                    Spacer()
                    Text(L10n.noTransactions)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(transactions.prefix(50).enumerated()), id: \.element.id) { idx, tx in
                        transactionRow(tx)
                        if idx < min(transactions.count, 50) - 1 {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func transactionRow(_ tx: TransactionRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: tx.action == "add" ? "plus.circle.fill"
                : tx.action == "delete" ? "trash.circle.fill"
                : "arrow.triangle.swap")
                .font(.title3)
                .foregroundStyle(tx.action == "add" ? .green
                    : tx.action == "delete" ? .red
                    : .orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(tx.ticker.uppercased())
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(tx.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatTransactionDate(tx.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func formatTransactionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return fmt.string(from: date)
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MM-dd"
        return fmt.string(from: date)
    }

    // MARK: Transaction Logging

    private func logTransaction(ticker: String, action: String, detail: String) {
        let record = TransactionRecord(
            ticker: ticker.uppercased(),
            action: action,
            detail: detail
        )
        modelContext.insert(record)
        try? modelContext.save()
    }

    // MARK: DCA Section

    private var dcaSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "dollarsign.arrow.circlepath")
                    .foregroundStyle(.orange)
                Text(L10n.dailyDCALabel)
                    .font(.headline)
            }

            // DCA amount input
            HStack(spacing: 12) {
                Text("$")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                TextField("0.00", value: $dcaAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.title2)
                    .fontWeight(.bold)
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // 1-click DCA buttons for each holding
            if !holdings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Execute")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                        ForEach(holdings) { holding in
                            HStack(spacing: 6) {
                                Text(holding.ticker.uppercased())
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(colorForHolding(holding))
                                Text("+ $100")
                                    .font(.caption)
                                    .monospacedDigit()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(colorForHolding(holding).opacity(0.1))
                            .clipShape(Capsule())
                            .onTapGesture {
                                quickDCA(holding: holding, amount: 100)
                            }
                        }
                    }
                }
            }

            Text(L10n.dcaFootnote)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onChange(of: dcaAmount) { _, _ in saveDCA() }
    }

    private func quickDCA(holding: Holding, amount: Double) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            holding.amountInvested += amount
            holding.currentValue += amount
            holding.recalculatePosition()
            try? modelContext.save()
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        logTransaction(ticker: holding.ticker, action: "add", detail: "DCA +$\(String(format: "%.0f", amount))")

        chatMessage = "DCA: +$\(String(format: "%.0f", amount)) to \(holding.ticker.uppercased())"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if chatMessage?.hasPrefix("DCA:") == true { chatMessage = nil }
            }
        }
    }

    // MARK: Core Actions

    /// Query-first upsert: if the ticker exists, adds to the position; otherwise inserts new.
    private func upsertHolding(ticker: String, name: String, amountInvested: Double, currentValue: Double) {
        guard !ticker.isEmpty, amountInvested > 0 else { return }

        if let existing = holdings.first(where: { $0.ticker.uppercased() == ticker.uppercased() }) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                existing.amountInvested += amountInvested
                existing.currentValue += currentValue
                if currentValue > 0 {
                    existing.currentDailyPrice = currentValue
                }
                existing.recalculatePosition()
                try? modelContext.save()
            }
            logTransaction(ticker: ticker, action: "add", detail: "+$\(String(format: "%.0f", amountInvested)) (total invested: $\(String(format: "%.0f", existing.amountInvested)))")
        } else {
            let price = currentValue > 0 ? currentValue : amountInvested
            let holding = Holding(
                ticker: ticker,
                name: name,
                amountInvested: amountInvested,
                currentValue: currentValue > 0 ? currentValue : amountInvested,
                currentDailyPrice: price,
                previousClose: price,
                sharesOwned: price > 0 ? amountInvested / price : 0
            )
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                modelContext.insert(holding)
                try? modelContext.save()
            }
            logTransaction(ticker: ticker, action: "add", detail: "New position: $\(String(format: "%.0f", amountInvested)) @ $\(String(format: "%.2f", price))")
        }
    }

    private func upsertHoldingFromForm() {
        let ticker = newTicker.trimmingCharacters(in: .whitespaces).uppercased()
        let name = newName.trimmingCharacters(in: .whitespaces)
        upsertHolding(ticker: ticker, name: name, amountInvested: newAmountInvested, currentValue: newCurrentValue)

        newTicker = ""
        newName = ""
        newAmountInvested = 0
        newCurrentValue = 0
        newDailyChange = 0
        newDailyChangePercent = 0
        showAddForm = false
    }

    // MARK: Daily Price Lazy Load

    private func performDailyPriceUpdateIfNeeded() {
        let today = calendarDayString()
        guard lastUpdateDate != today else { return }

        for holding in holdings {
            let mockPrice = generateMockPrice(for: holding)
            holding.updateDailyPrice(to: mockPrice)
        }
        try? modelContext.save()
        lastUpdateDate = today
    }

    private func generateMockPrice(for holding: Holding) -> Double {
        let basePrice = holding.currentDailyPrice > 0 ? holding.currentDailyPrice : (holding.safeAmountInvested > 0 ? holding.safeAmountInvested : 100)
        let changePercent = Double.random(in: -0.03...0.03)
        let newPrice = basePrice * (1 + changePercent)
        return newPrice.isNaN || newPrice.isInfinite ? basePrice : newPrice
    }

    private func calendarDayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func loadDCA() {
        if let existing = financeData.first {
            dcaAmount = existing.dailyDCAAmount
        }
    }

    private func saveDCA() {
        if let existing = financeData.first {
            existing.dailyDCAAmount = dcaAmount
        } else {
            let new = FinanceData(dailyDCAAmount: dcaAmount)
            modelContext.insert(new)
        }
        try? modelContext.save()
    }
}

// MARK: - Ticker Database

private let tickerDatabase: [String: String] = [
    "AAPL": "Apple Inc.",
    "MSFT": "Microsoft Corp.",
    "GOOGL": "Alphabet Inc.",
    "AMZN": "Amazon.com Inc.",
    "TSLA": "Tesla Inc.",
    "NVDA": "Nvidia Corp.",
    "META": "Meta Platforms Inc.",
    "NFLX": "Netflix Inc.",
    "BRK.B": "Berkshire Hathaway",
    "JPM": "JPMorgan Chase",
    "V": "Visa Inc.",
    "JNJ": "Johnson & Johnson",
    "WMT": "Walmart Inc.",
    "PG": "Procter & Gamble",
    "KO": "Coca-Cola Co.",
    "DIS": "Walt Disney Co.",
    "NKE": "Nike Inc.",
    "CRM": "Salesforce Inc.",
    "ADBE": "Adobe Inc.",
    "PYPL": "PayPal Holdings",
    "INTC": "Intel Corp.",
    "AMD": "Advanced Micro Devices",
    "SPOT": "Spotify Technology",
    "UBER": "Uber Technologies",
    "ABNB": "Airbnb Inc.",
    "SNOW": "Snowflake Inc.",
    "PLTR": "Palantir Technologies",
    "COIN": "Coinbase Global",
    "QQQ": "Invesco QQQ Trust",
    "SPY": "SPDR S&P 500 ETF",
    "VOO": "Vanguard S&P 500 ETF",
    "VTI": "Vanguard Total Stock Market",
    "BND": "Vanguard Total Bond Market",
    "ARKK": "ARK Innovation ETF",
    "SQ": "Block Inc.",
    "SHOP": "Shopify Inc.",
    "SNAP": "Snap Inc.",
    "RBLX": "Roblox Corp.",
    "BA": "Boeing Co.",
    "XOM": "Exxon Mobil Corp.",
    "CVX": "Chevron Corp.",
    "PFE": "Pfizer Inc.",
    "MRNA": "Moderna Inc.",
    "BABA": "Alibaba Group",
    "TCEHY": "Tencent Holdings",
    "NIO": "NIO Inc.",
    "RIVN": "Rivian Automotive",
    "LCID": "Lucid Group",
    "GME": "GameStop Corp.",
    "AMC": "AMC Entertainment"
]
