import Foundation

// MARK: - Localized Strings

enum L10n {

    private static var lang: String {
        UserDefaults.standard.string(forKey: "language") ?? "en"
    }

    // Tab Bar
    static var schedule: String { lang == "zh-Hans" ? "日程" : "Schedule" }
    static var vision: String { lang == "zh-Hans" ? "远景" : "Vision" }

    // Header
    static var lifeOS: String { "Life OS" }

    // Modules
    static var modules: String { lang == "zh-Hans" ? "模块" : "Modules" }
    static var study: String { lang == "zh-Hans" ? "学习" : "Study" }
    static var health: String { lang == "zh-Hans" ? "健康" : "Health" }
    static var finance: String { lang == "zh-Hans" ? "理财" : "Finance" }

    // Settings
    static var settings: String { lang == "zh-Hans" ? "设置" : "Settings" }
    static var appearance: String { lang == "zh-Hans" ? "外观" : "Appearance" }
    static var language: String { lang == "zh-Hans" ? "语言" : "Language" }
    static var light: String { lang == "zh-Hans" ? "浅色" : "Light" }
    static var dark: String { lang == "zh-Hans" ? "深色" : "Dark" }
    static var system: String { lang == "zh-Hans" ? "跟随系统" : "System" }
    static var englishLabel: String { "English" }
    static var chineseLabel: String { "简体中文" }
    static var close: String { lang == "zh-Hans" ? "关闭" : "Close" }
    static var save: String { lang == "zh-Hans" ? "保存" : "Save" }
    static var cancel: String { lang == "zh-Hans" ? "取消" : "Cancel" }

    // Input
    static var inputPlaceholder: String { lang == "zh-Hans" ? "在想什么？" : "What's on your mind?" }
    static var taskTitlePlaceholder: String { lang == "zh-Hans" ? "任务名称" : "Task Title" }
    static var timeDisplayPlaceholder: String { lang == "zh-Hans" ? "例如: 早上, 晚上8点" : "e.g. Morning, 8:00 PM" }

    // Vision
    static var visionOverview: String { lang == "zh-Hans" ? "远景与概览" : "Vision & Overview" }
    static var thisWeekFocus: String { lang == "zh-Hans" ? "本周聚焦" : "This Week's Focus" }
    static var thisMonthFocus: String { lang == "zh-Hans" ? "本月聚焦" : "This Month's Focus" }
    static var weekFocusSheet: String { lang == "zh-Hans" ? "本周聚焦" : "Week Focus" }
    static var monthFocusSheet: String { lang == "zh-Hans" ? "本月聚焦" : "Month Focus" }
    static var tapToSetWeek: String { lang == "zh-Hans" ? "点击设置本周重点…" : "Tap to set your focus for this week..." }
    static var tapToSetMonth: String { lang == "zh-Hans" ? "点击设置本月重点…" : "Tap to set your focus for this month..." }
    static var aiSummarize: String { lang == "zh-Hans" ? "AI 总结" : "AI Summarize" }
    static var thinking: String { lang == "zh-Hans" ? "思考中…" : "Thinking..." }
    static var dreamBoard: String { lang == "zh-Hans" ? "梦想板" : "Dream Board" }
    static var dreamBoardHint: String { lang == "zh-Hans" ? "添加图片与文字，可视化你的愿景。" : "Add images and text to visualize your vision." }
    static var addImage: String { lang == "zh-Hans" ? "添加图片" : "Add Image" }
    static var dreamTextPlaceholder: String { lang == "zh-Hans" ? "写下你的梦想…" : "Write your dream..." }

    // Schedule
    static var noTasks: String { lang == "zh-Hans" ? "暂无任务" : "No tasks yet" }
    static var getStarted: String { lang == "zh-Hans" ? "在下方输入以开始" : "Type something below to get started" }
    static var today: String { lang == "zh-Hans" ? "今天" : "Today" }
    static var tomorrow: String { lang == "zh-Hans" ? "明天" : "Tomorrow" }
    static var task: String { lang == "zh-Hans" ? "任务" : "Task" }
    static var taskNotes: String { lang == "zh-Hans" ? "备注" : "Notes" }
    static var delete: String { lang == "zh-Hans" ? "删除" : "Delete" }
    static var fullDetails: String { lang == "zh-Hans" ? "完整详情" : "Full Details" }

    // Clarify
    static var clarificationNeeded: String { lang == "zh-Hans" ? "需要进一步说明" : "Clarification Needed" }
    static var ok: String { "OK" }
    static var provideDetails: String { lang == "zh-Hans" ? "请提供更多细节。" : "Please provide more details." }

    // Map
    static var navigateWith: String { lang == "zh-Hans" ? "选择导航" : "Navigate with" }
    static var appleMaps: String { "Apple Maps" }

    // Health
    static var bodyMetrics: String { lang == "zh-Hans" ? "身体指标" : "Body Metrics" }
    static var genderLabel: String { lang == "zh-Hans" ? "性别" : "Gender" }
    static var male: String { lang == "zh-Hans" ? "男" : "Male" }
    static var female: String { lang == "zh-Hans" ? "女" : "Female" }
    static var ageLabel: String { lang == "zh-Hans" ? "年龄" : "Age" }
    static var weightLabel: String { lang == "zh-Hans" ? "体重" : "Weight" }
    static var targetWeightLabel: String { lang == "zh-Hans" ? "目标体重" : "Target Weight" }
    static var heightLabel: String { lang == "zh-Hans" ? "身高" : "Height" }
    static var bmiLabel: String { "BMI" }
    static var aiHealthAnalyst: String { lang == "zh-Hans" ? "AI 健康分析师" : "AI Health Analyst" }
    static var analyzingHealth: String { lang == "zh-Hans" ? "分析中…" : "Analyzing..." }
    static var runHealthAnalysis: String { lang == "zh-Hans" ? "运行健康分析" : "Run Health Analysis" }
    static var healthAnalysisHeader: String { lang == "zh-Hans" ? "健康评估" : "Health Assessment" }

    // Finance
    static var portfolio: String { lang == "zh-Hans" ? "投资组合" : "Portfolio" }
    static var addHolding: String { lang == "zh-Hans" ? "添加持仓" : "Add Holding" }
    static var tickerPlaceholder: String { lang == "zh-Hans" ? "代码 (如 AAPL)" : "Ticker (e.g. AAPL)" }
    static var namePlaceholder: String { lang == "zh-Hans" ? "名称 (如 Apple Inc.)" : "Name (e.g. Apple Inc.)" }
    static var amountInvested: String { lang == "zh-Hans" ? "投入金额" : "Amount Invested" }
    static var currentValueLabel: String { lang == "zh-Hans" ? "当前市值" : "Current Value" }
    static var analyticsDashboard: String { lang == "zh-Hans" ? "分析面板" : "Analytics Dashboard" }
    static var totalInvested: String { lang == "zh-Hans" ? "总投入" : "Total Invested" }
    static var totalValue: String { lang == "zh-Hans" ? "总市值" : "Total Value" }
    static var totalPnL: String { lang == "zh-Hans" ? "总盈亏" : "Total PnL" }
    static var dailyChangeLabel: String { lang == "zh-Hans" ? "日变动" : "Daily Change" }
    static var pnlPercentLabel: String { lang == "zh-Hans" ? "盈亏 %" : "PnL %" }

    // Study / Focus
    static var noStudyTasks: String { lang == "zh-Hans" ? "暂无学习任务" : "No Study Tasks" }
    static var createStudyHint: String { lang == "zh-Hans" ? "请在日程页面创建学习任务。" : "Create a study task from the Schedule tab." }
    static var focusEngine: String { lang == "zh-Hans" ? "专注引擎" : "Focus Engine" }
    static var focusHistory: String { lang == "zh-Hans" ? "专注历史" : "Focus History" }
    static var noFocusSessions: String { lang == "zh-Hans" ? "暂无专注记录" : "No focus sessions yet" }
    static var startFocusHint: String { lang == "zh-Hans" ? "开始一次专注以记录你的进度。" : "Start a focus session to track your progress." }
    static var setsLabel: String { lang == "zh-Hans" ? "组数" : "Sets" }
    static func setIndicator(_ current: Int, _ total: Int) -> String {
        lang == "zh-Hans"
            ? "第 \(current)/\(total) 组"
            : "Set \(current)/\(total)"
    }
    static var pomodoroMethod: String { lang == "zh-Hans" ? "番茄钟" : "Pomodoro" }
    static var randomPromptMethod: String { lang == "zh-Hans" ? "随机提示" : "Random Prompt" }
    static var studyContentLabel: String { lang == "zh-Hans" ? "学习内容" : "Study Content" }
    static var studyContentPlaceholder: String { lang == "zh-Hans" ? "输入本次学习内容…" : "Enter study content for this session..." }
    static var sessionComplete: String { lang == "zh-Hans" ? "专注完成" : "Session Complete" }
    static var greatWork: String { lang == "zh-Hans" ? "做得好！已记录到专注历史。" : "Great work! Saved to focus history." }
    static var start: String { lang == "zh-Hans" ? "开始" : "Start" }
    static var pause: String { lang == "zh-Hans" ? "暂停" : "Pause" }
    static var reset: String { lang == "zh-Hans" ? "重置" : "Reset" }
    static var focusLabel: String { lang == "zh-Hans" ? "专注" : "Focus" }
    static var breakLabel: String { lang == "zh-Hans" ? "休息" : "Break" }
    static var readyLabel: String { lang == "zh-Hans" ? "就绪" : "Ready" }
    static var learningDuration: String { lang == "zh-Hans" ? "时长" : "Duration" }
    static var minutesUnit: String { lang == "zh-Hans" ? "分钟" : "min" }
    static var yesterdayDelta: String { lang == "zh-Hans" ? "昨日体重变化" : "Yesterday's Weight Change" }
    static var deltaPlaceholder: String { lang == "zh-Hans" ? "+0.5 或 -0.3" : "+0.5 or -0.3" }
    static func targetGap(_ kg: Double) -> String {
        let absStr = String(format: "%.1f", abs(kg))
        return lang == "zh-Hans"
            ? "离目标体重还有 \(absStr) kg"
            : "\(absStr) kg away from target"
    }
    static func targetGapOver(_ kg: Double) -> String {
        let absStr = String(format: "%.1f", abs(kg))
        return lang == "zh-Hans"
            ? "已超过目标体重 \(absStr) kg"
            : "\(absStr) kg over target"
    }
    static var timeTomorrow: String { lang == "zh-Hans" ? "明天" : "Tomorrow" }
    static var timeYesterday: String { lang == "zh-Hans" ? "昨天" : "Yesterday" }
    static var startSession: String { lang == "zh-Hans" ? "开始专注" : "Start Session" }
    static var endSession: String { lang == "zh-Hans" ? "结束专注" : "End Session" }
    static var methodLabel: String { lang == "zh-Hans" ? "方式" : "Method" }
    static var titleLabel: String { lang == "zh-Hans" ? "标题" : "Title" }
    static var timeLabel: String { lang == "zh-Hans" ? "时间" : "Time" }
    static var timeStart: String { lang == "zh-Hans" ? "开始" : "Start" }
    static var timeEnd: String { lang == "zh-Hans" ? "结束" : "End" }
    static var sessionActiveHint: String { lang == "zh-Hans" ? "专注进行中 — 提示音将随机响起" : "Session active — prompts appear randomly" }
    static var randomPromptDescription: String { lang == "zh-Hans" ? "随机反思提示将在不可预测的间隔（1-5 分钟）出现，帮助你检查专注度和加深学习。" : "Random reflection prompts will appear at unpredictable intervals (1-5 min) to check your focus and deepen learning." }

    // Task Detail
    static var taskReview: String { lang == "zh-Hans" ? "任务回顾" : "Task Review" }
    static func reviewScheduledPrompt(_ timeDisplay: String) -> String {
        lang == "zh-Hans"
            ? "该任务原定于 \(timeDisplay)。进展如何？"
            : "This task was scheduled for \(timeDisplay). How did it go?"
    }
    static var completionRateLabel: String { lang == "zh-Hans" ? "完成度" : "Completion Rate" }
    static var thoughtsExcuses: String { lang == "zh-Hans" ? "想法 / 借口" : "Thoughts / Excuses" }
    static var howDidItGo: String { lang == "zh-Hans" ? "进展如何？有什么阻碍？" : "How did it go? Any blockers?" }
    static var submitToAI: String { lang == "zh-Hans" ? "提交给 AI 教练" : "Submit to AI Coach" }
    static var reflectingLabel: String { lang == "zh-Hans" ? "反思中…" : "Reflecting..." }
    static var aiCoach: String { lang == "zh-Hans" ? "AI 教练" : "AI Coach" }
    static var markAsDone: String { lang == "zh-Hans" ? "标记完成 / 回顾" : "Mark as Done / Review" }

    // General
    static var generalTask: String { lang == "zh-Hans" ? "通用任务" : "General Task" }
    static var generalTaskHint: String { lang == "zh-Hans" ? "此任务类型无专属模块。请在下方标记进度。" : "No special module for this task type. Mark your progress below." }
    static var focusSession: String { lang == "zh-Hans" ? "专注时段" : "Focus Session" }

    // Legacy (still used by TaskDetailView and TaskEditSheet)
    static var healthTracker: String { lang == "zh-Hans" ? "健康追踪" : "Health Tracker" }
    static var bmiCalculator: String { lang == "zh-Hans" ? "BMI 计算器" : "BMI Calculator" }
    static var dietWindow: String { lang == "zh-Hans" ? "饮食窗口 (16:8 禁食)" : "Diet Window (16:8 Fasting)" }
    static var whatDidYouEat: String { lang == "zh-Hans" ? "吃了什么？" : "What did you eat?" }
    static var assetAllocation: String { lang == "zh-Hans" ? "资产配置" : "Asset Allocation" }
    static var dailyDCALabel: String { lang == "zh-Hans" ? "每日定投 (DCA)" : "Daily DCA (Dollar Cost Averaging)" }
    static var dcaFootnote: String { lang == "zh-Hans" ? "持续每日投资，复利增长。" : "Consistent daily investment compounds over time." }
    static var visionBoard: String { lang == "zh-Hans" ? "愿景板" : "Vision Board" }
    static var visionBoardHint: String { lang == "zh-Hans" ? "可视化你的长期目标。在此反思你的远大图景。" : "Visualize your long-term goals. Use this space to reflect on your bigger picture." }
    static var portfolioOverview: String { lang == "zh-Hans" ? "投资组合概览" : "Portfolio Overview" }

    // Task State
    static var completed: String { lang == "zh-Hans" ? "已完成" : "Completed" }
    static var pending: String { lang == "zh-Hans" ? "待完成" : "Pending" }

    // Micro-Step AI
    static var easyStart: String { lang == "zh-Hans" ? "轻松开始" : "Easy Start" }
    static var easyStartHint: String { lang == "zh-Hans" ? "AI 将任务拆解为微小步骤" : "AI breaks this into tiny micro-steps" }
    static var breakingDown: String { lang == "zh-Hans" ? "拆解中…" : "Breaking down..." }
    static var microStepsCreated: String { lang == "zh-Hans" ? "已创建 %d 个微步骤" : "%d micro-steps created" }
    static var reschedule: String { lang == "zh-Hans" ? "重新安排" : "Reschedule" }
    static var rescheduleTask: String { lang == "zh-Hans" ? "推迟任务" : "Reschedule Task" }
    static var newDate: String { lang == "zh-Hans" ? "新日期" : "New Date" }
    static var tryEasyStart: String { lang == "zh-Hans" ? "觉得太难？让 AI 帮你拆解成微小步骤。" : "Feeling overwhelmed? Let AI break it into tiny steps." }

    // Finance NLP
    static var financeChat: String { lang == "zh-Hans" ? "投资助手" : "Portfolio Assistant" }
    static var financeChatPlaceholder: String { lang == "zh-Hans" ? "例如：买了 $5000 苹果股票，现价 $185…" : "e.g. Bought $5000 of Apple at $185..." }
    static var fuzzyMatch: String { lang == "zh-Hans" ? "模糊匹配" : "Fuzzy Match" }
    static var noHoldings: String { lang == "zh-Hans" ? "暂无持仓" : "No holdings yet" }
    static var tapToAdd: String { lang == "zh-Hans" ? "点击 + 添加持仓" : "Tap + to add your first holding" }

    // Diet Module
    static var diet: String { lang == "zh-Hans" ? "饮食" : "Diet" }
    static var addMeal: String { lang == "zh-Hans" ? "记录餐食" : "Log Meal" }
    static var mealPlaceholder: String { lang == "zh-Hans" ? "例如：吃了牛肉和鸡蛋…" : "e.g. Had beef and eggs..." }
    static var estimateCalories: String { lang == "zh-Hans" ? "估算卡路里" : "Estimate Calories" }
    static var estimatedCalories: String { lang == "zh-Hans" ? "预估热量" : "Est. Calories" }
    static var kcal: String { "kcal" }

    // Sleep Module
    static var sleep: String { lang == "zh-Hans" ? "睡眠" : "Sleep" }
    static var hoursSleptLabel: String { lang == "zh-Hans" ? "睡眠时长" : "Hours Slept" }
    static var addSleep: String { lang == "zh-Hans" ? "记录睡眠" : "Log Sleep" }
    static var sleepQualityPlaceholder: String { lang == "zh-Hans" ? "睡眠质量备注…" : "Quality notes..." }
    static var hours: String { lang == "zh-Hans" ? "小时" : "hrs" }
    static var weeklyAverage: String { lang == "zh-Hans" ? "周平均" : "Weekly Avg" }

    // Mood Module
    static var mood: String { lang == "zh-Hans" ? "情绪" : "Mood" }
    static var logMood: String { lang == "zh-Hans" ? "记录心情" : "Log Mood" }

    // Transaction History
    static var transactionHistory: String { lang == "zh-Hans" ? "交易记录" : "Transaction History" }
    static var noTransactions: String { lang == "zh-Hans" ? "暂无交易记录" : "No transactions yet" }
    static var transactionAdded: String { lang == "zh-Hans" ? "已添加" : "Added" }
    static var transactionUpdated: String { lang == "zh-Hans" ? "已更新" : "Updated" }
    static var transactionDeleted: String { lang == "zh-Hans" ? "已删除" : "Removed" }

    // JSON Import
    static var importData: String { lang == "zh-Hans" ? "导入数据" : "Import Data" }
    static var importTitle: String { lang == "zh-Hans" ? "导入策略" : "Import Strategy" }
    static var importMessage: String { lang == "zh-Hans" ? "选择导入方式" : "Choose import method" }
    static var overwriteOption: String { lang == "zh-Hans" ? "完全覆盖" : "Completely Overwrite" }
    static var mergeOption: String { lang == "zh-Hans" ? "智能合并" : "Smart Merge" }
    static var importSuccess: String { lang == "zh-Hans" ? "导入成功" : "Import Successful" }
    static var importFailed: String { lang == "zh-Hans" ? "导入失败" : "Import Failed" }

    // Schedule History
    static var scheduleHistory: String { lang == "zh-Hans" ? "历史日程" : "Schedule History" }
    static var pastTasks: String { lang == "zh-Hans" ? "过往任务" : "Past Tasks" }
    static var overdue: String { lang == "zh-Hans" ? "已过期" : "Overdue" }
    static var incomplete: String { lang == "zh-Hans" ? "未完成" : "Incomplete" }
    static var noPastTasks: String { lang == "zh-Hans" ? "暂无过往任务" : "No past tasks" }

    // Health History
    static var healthHistory: String { lang == "zh-Hans" ? "健康历史" : "Health History" }
    static var noHealthHistory: String { lang == "zh-Hans" ? "暂无健康记录" : "No health records yet" }
    static var stepsLabel: String { lang == "zh-Hans" ? "步数" : "Steps" }
    static var stepsToday: String { lang == "zh-Hans" ? "今日步数" : "Today's Steps" }
    static var healthkitDenied: String { lang == "zh-Hans" ? "健康数据权限未开启" : "Health data access denied" }
    static var enableHealthKit: String { lang == "zh-Hans" ? "请在设置中开启健康数据权限" : "Enable Health access in Settings" }
    static var sleepNotesHint: String { lang == "zh-Hans" ? "最近没休息好？添加备注…" : "Didn't rest well recently? Add notes here..." }

    // Translation Toggle
    static var translate: String { lang == "zh-Hans" ? "翻译" : "Translate" }
    static var showOriginal: String { lang == "zh-Hans" ? "显示原文" : "Show Original" }

    // AI Summary Cooldown
    static var generateBriefing: String { lang == "zh-Hans" ? "生成简报" : "Generate Briefing" }
    static var briefingReady: String { lang == "zh-Hans" ? "新简报已就绪" : "New briefing available" }
    static var nextBriefingIn: String { lang == "zh-Hans" ? "下次简报可用时间" : "Next briefing available in" }

    // Health Module Headers
    static var thisWeek: String { lang == "zh-Hans" ? "本周" : "This Week" }
    static var noDataThisWeek: String { lang == "zh-Hans" ? "本周暂无数据" : "No data this week" }
    static var calorieAI: String { lang == "zh-Hans" ? "AI 热量分析" : "AI Calorie Analysis" }
    static var analyzing: String { lang == "zh-Hans" ? "分析中…" : "Analyzing..." }
}
