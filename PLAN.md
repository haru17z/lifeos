# Project: Life OS - iOS Client (MVP Phase)

## 1. Project Overview
A highly automated, AI-driven personal Life Operating System designed to reduce cognitive friction and outsource willpower. The app emphasizes a premium, native Apple aesthetic (frosted glass, large corner radii, high contrast) and leverages AI to parse user intentions into structured, actionable timelines.

## 2. Tech Stack & Architecture
- **Framework:** SwiftUI (Targeting iOS 17+)
- **Architecture:** MVVM (Model-View-ViewModel)
- **Persistence:** SwiftData (Local storage for MVP)
- **Notifications:** UserNotifications framework (Local push notifications)
- **AI Integration:** A generic Network Manager setup to call an LLM API (e.g., DeepSeek/OpenAI compatible endpoint) for Natural Language to JSON parsing.

## 3. UI/UX Design Guidelines
- **Typography:** SF Pro Rounded for headings, SF Pro Text for body.
- **Materials:** Heavy use of `.ultraThinMaterial` and `.regularMaterial` for backgrounds to create depth.
- **Colors:** Deep blacks, crisp whites, and vibrant, subtle gradients for accents (e.g., highlighting an active "16:8 Fasting" block).
- **Animations:** `.spring()` animations for all state changes; zero harsh transitions.

## 4. Phase 1: MVP Execution Plan (Do not proceed to next step until current is verified)

### Step 1: Project Setup & Core Data Models
- Initialize the SwiftUI project.
- Create the SwiftData model `LifeTask`.
  - Properties: `id` (UUID), `title` (String), `scheduledTime` (Date), `location` (String, optional), `taskType` (Enum: study, health, finance, vision, general), `isCompleted` (Bool).

### Step 2: The "Brain" - AI Parser Service
- Create an `AIManager` service class.
- Implement a function `parseInput(text: String) async throws -> LifeTask`.
- For MVP, mock the API call first: simulate a delay and return a hardcoded `LifeTask` (e.g., input: "Tomorrow at 2 PM review CS 9618 algorithms", returns parsed object). Once the mock works, we will implement the actual URLSession network call to a standard chat completions endpoint.

### Step 3: The "Inbox" & Timeline UI
- Build the `HomeView`.
- Top section: A sleek, Apple-style text field (Spotlight-esque) where the user can dump thoughts/tasks.
- Bottom section: A vertical timeline (using `ScrollView` and `VStack`) displaying today's `LifeTask` objects fetched via `@Query`.
- Action: When a user hits "enter" in the text field, show a loading state, pass text to `AIManager`, and save the resulting `LifeTask` to SwiftData.

### Step 4: The Notification Engine
- Create a `NotificationManager` singleton.
- Request user permission for notifications on app launch.
- When a `LifeTask` is saved with a future `scheduledTime`, automatically schedule a local push notification.
- Add a custom notification sound placeholder.

## 5. Development Directives for Claude
- Write clean, modular SwiftUI code. Separate Views from ViewModels.
- Prioritize safe error handling (use `do-catch` blocks and display user-friendly error alerts).
- Do not hallucinate massive third-party libraries; stick to native Apple frameworks as much as possible to maintain performance.