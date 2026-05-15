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
    static var dreamComingSoon: String { lang == "zh-Hans" ? "长期愿景即将上线" : "Long-term vision coming soon" }

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
    static var other: String { lang == "zh-Hans" ? "其他" : "Other" }
    static var ageLabel: String { lang == "zh-Hans" ? "年龄" : "Age" }
    static var weightLabel: String { lang == "zh-Hans" ? "体重" : "Weight" }
    static var heightLabel: String { lang == "zh-Hans" ? "身高" : "Height" }
    static var bmiLabel: String { "BMI" }
    static var saveProfile: String { lang == "zh-Hans" ? "保存资料" : "Save Profile" }
    static var dailyMeals: String { lang == "zh-Hans" ? "每日饮食" : "Daily Meals" }
    static var breakfast: String { lang == "zh-Hans" ? "早餐" : "Breakfast" }
    static var lunch: String { lang == "zh-Hans" ? "午餐" : "Lunch" }
    static var dinner: String { lang == "zh-Hans" ? "晚餐" : "Dinner" }
    static var weightTracking: String { lang == "zh-Hans" ? "体重追踪" : "Weight Tracking" }
    static var weightChangeLabel: String { lang == "zh-Hans" ? "体重变化" : "Weight change (kg)" }
    static var logLabel: String { lang == "zh-Hans" ? "记录" : "Log" }
    static var recentChanges: String { lang == "zh-Hans" ? "最近变化:" : "Recent changes:" }
    static var aiDietSuggestions: String { lang == "zh-Hans" ? "AI 饮食与运动建议" : "AI Diet & Exercise Suggestions" }
    static var getAISuggestions: String { lang == "zh-Hans" ? "获取 AI 建议" : "Get AI Suggestions" }
    static var aiSuggestionHeader: String { lang == "zh-Hans" ? "AI 建议" : "AI Suggestion" }
    static var whatDidYouEat: String { lang == "zh-Hans" ? "吃了什么？" : "What did you eat?" }
    static var dietWindow: String { lang == "zh-Hans" ? "饮食窗口 (16:8 禁食)" : "Diet Window (16:8 Fasting)" }

    // Finance
    static var assetAllocation: String { lang == "zh-Hans" ? "资产配置" : "Asset Allocation" }
    static var dailyDCALabel: String { lang == "zh-Hans" ? "每日定投 (DCA)" : "Daily DCA (Dollar Cost Averaging)" }
    static var dcaFootnote: String { lang == "zh-Hans" ? "持续每日投资，复利增长。" : "Consistent daily investment compounds over time." }
    static var nasdaq100: String { "Nasdaq 100" }
    static var sp500: String { "S&P 500" }
    static var btc: String { "BTC" }
    static var cash: String { lang == "zh-Hans" ? "现金" : "Cash" }
    static var healthTracker: String { lang == "zh-Hans" ? "健康追踪" : "Health Tracker" }
    static var bmiCalculator: String { lang == "zh-Hans" ? "BMI 计算器" : "BMI Calculator" }

    // Study
    static var noStudyTasks: String { lang == "zh-Hans" ? "暂无学习任务" : "No Study Tasks" }
    static var createStudyHint: String { lang == "zh-Hans" ? "请在日程页面创建学习任务。" : "Create a study task from the Schedule tab." }

    // Task Detail
    static var taskReview: String { lang == "zh-Hans" ? "任务回顾" : "Task Review" }
    static var completionRateLabel: String { lang == "zh-Hans" ? "完成度" : "Completion Rate" }
    static var thoughtsExcuses: String { lang == "zh-Hans" ? "想法 / 借口" : "Thoughts / Excuses" }
    static var howDidItGo: String { lang == "zh-Hans" ? "进展如何？有什么阻碍？" : "How did it go? Any blockers?" }
    static var submitToAI: String { lang == "zh-Hans" ? "提交给 AI 教练" : "Submit to AI Coach" }
    static var reflectingLabel: String { lang == "zh-Hans" ? "反思中…" : "Reflecting..." }
    static var aiCoach: String { lang == "zh-Hans" ? "AI 教练" : "AI Coach" }
    static var markAsDone: String { lang == "zh-Hans" ? "标记完成 / 回顾" : "Mark as Done / Review" }

    // Modules in Detail
    static var visionBoard: String { lang == "zh-Hans" ? "愿景板" : "Vision Board" }
    static var visionBoardHint: String { lang == "zh-Hans" ? "可视化你的长期目标。在此反思你的远大图景。" : "Visualize your long-term goals. Use this space to reflect on your bigger picture." }
    static var generalTask: String { lang == "zh-Hans" ? "通用任务" : "General Task" }
    static var generalTaskHint: String { lang == "zh-Hans" ? "此任务类型无专属模块。请在下方标记进度。" : "No special module for this task type. Mark your progress below." }
    static var focusSession: String { lang == "zh-Hans" ? "专注时段" : "Focus Session" }
    static var portfolioOverview: String { lang == "zh-Hans" ? "投资组合概览" : "Portfolio Overview" }
}
