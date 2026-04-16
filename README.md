<div align="center">

# MeetCost — Meeting Cost Calculator

**Know exactly what every meeting costs. In real time.**

A cross-platform Apple-native meeting cost tracker built with SwiftUI, SwiftData, and Swift Charts.
iPhone, iPad, Mac, and Apple Watch — 1,747 lines of Swift, zero external dependencies.

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?logo=swift&logoColor=white)](https://swift.org)
[![iOS 18+](https://img.shields.io/badge/iOS-18%2B-000000?logo=apple&logoColor=white)](https://developer.apple.com/ios/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-blue?logo=swift&logoColor=white)](https://developer.apple.com/swiftui/)
[![SwiftData](https://img.shields.io/badge/SwiftData-orange?logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftdata/)
[![Swift Charts](https://img.shields.io/badge/Charts-green?logo=swift&logoColor=white)](https://developer.apple.com/documentation/charts)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Zero Dependencies](https://img.shields.io/badge/Dependencies-0-brightgreen)](#tech-stack)

</div>

---

## Screenshots

<table>
  <tr>
    <td align="center" width="25%">
      <img src="screenshots/raw/01_meeting_list.png" width="220" alt="Meeting List" /><br>
      <sub><b>Meeting List</b></sub>
    </td>
    <td align="center" width="25%">
      <img src="screenshots/raw_v2/ipad/fr-FR/light/01_landing.png" width="220" alt="Live Cost Ticker" /><br>
      <sub><b>Live Cost Ticker</b></sub>
    </td>
    <td align="center" width="25%">
      <img src="screenshots/raw_v2/iphone/en-US/light/03_running_alternate.png" width="220" alt="Running Alternate" /><br>
      <sub><b>Running Alternate</b></sub>
    </td>
    <td align="center" width="25%">
      <img src="screenshots/raw_v2/iphone/zh-Hans/dark/02_running_primary.png" width="260" alt="iPad" /><br>
      <sub><b>iPad</b></sub>
    </td>
  </tr>
</table>

---

## Features

| | Feature | Description |
|---|---|---|
| **Cost Tracking** | Live cost ticker | Per-second cost updates via `TimelineView` — no timers, no background tasks |
| **Concurrency** | Multiple meetings | Run several meetings simultaneously with independent pause/resume |
| **Currency** | Multi-currency | Each participant carries their own currency; converted live via exchange rates |
| **Resources** | Conflict detection | Rooms, projectors, and equipment can only attend one running meeting at a time |
| **Analytics** | 5-chart dashboard | Interactive Swift Charts with full `AXChartDescriptorRepresentable` accessibility |
| **Sync** | CloudKit | SwiftData with CloudKit backend — seamless cross-device sync |
| **Adaptive UI** | Platform-native | `NavigationSplitView` on iPad/Mac, `NavigationStack` on iPhone, landscape cost board |
| **Localization** | 11 languages | English, French, Spanish, German, Japanese, Russian, Arabic, Hindi, Portuguese (BR), Chinese (Simplified), Bengali |
| **Accessibility** | Full VoiceOver | Labels, hints, chart descriptors, reduce-motion support, Dynamic Type |
| **Privacy** | Zero data collection | No tracking, no analytics, no sensitive permissions |

---

## Architecture

MeetCost follows **MVVM with SwiftData**, using Apple's `@Observable` and `@Model` macros for clean reactive data flow. The entire app runs on pure Swift concurrency — no GCD, no Combine, no Dispatch.

```mermaid
flowchart TB
    subgraph Views ["Views — Platform Adaptive UI"]
        direction LR
        TV["TabView\n(App Root)"]
        SV["NavigationSplitView\n(iPad / Mac)"]
        SK["NavigationStack\n(iPhone)"]
        LB["LiveBoard\n(Landscape)"]
        ST["Statistics\nDashboard"]
        PM["Participant\nManagement"]
    end

    subgraph Models ["Models — SwiftData + CloudKit"]
        direction LR
        MM["MeetingModel\n(@Model)"]
        MP["MeetingParticipant\n(@Model)"]
        MM <-->|"many-to-many"| MP
    end

    subgraph Service ["Service Layer"]
        ERS["ExchangeRateService\n(@Observable @MainActor)"]
        API["open.er-api.com\nUSD base rates"]
    end

    subgraph Platform ["Platform Detection"]
        HSC["horizontalSizeClass"]
    end

    TV --> HSC
    HSC -->|".regular"| SV
    HSC -->|".compact"| SK
    HSC -->|"landscape"| LB

    Views <-->|"@Query / @Bindable"| Models
    Views -->|"async/await"| Service
    ERS -->|"URLSession\nasync/await"| API
    Models <-->|"CloudKit Sync"| CK[(iCloud)]

    style Views fill:#1a73e8,color:#fff
    style Models fill:#e8710a,color:#fff
    style Service fill:#0d904f,color:#fff
    style Platform fill:#7b1fa2,color:#fff
```

---

## Timer Architecture

The timer is MeetCost's key differentiator. Instead of `Timer`, `DispatchSourceTimer`, or background tasks, it uses **pure timestamp arithmetic** that survives app backgrounding without `BGTaskScheduler`.

```mermaid
sequenceDiagram
    participant U as User
    participant V as TimelineView
    participant M as MeetingModel

    U->>M: Tap Start
    activate M
    M->>M: meetingStart = Date.now
    M->>M: isRunning = true

    loop Every 1 second
        V->>M: Read liveElapsed
        M-->>V: Date.now − meetingStart − totalPausedDuration
        V->>V: Display cost = elapsed × Σ(hourlyRates)
    end

    U->>M: Tap Pause
    M->>M: pausedAt = Date.now

    Note over V,M: TimelineView still ticks,<br/>but elapsed freezes at pausedAt

    U->>M: Tap Resume
    M->>M: totalPausedDuration += Date.now − pausedAt
    M->>M: pausedAt = nil

    loop Every 1 second
        V->>M: Read liveElapsed
        M-->>V: Date.now − meetingStart − totalPausedDuration
    end

    U->>M: Tap Stop
    M->>M: meetingEnd = Date.now
    M->>M: meetingCost = finalElapsed × Σ(convertedRates)
    M->>M: isRunning = false
    deactivate M

    Note over M: Cost materialized once at stop.<br/>No background tasks ever needed.
```

**Why this matters:**
- App can be killed and relaunched — elapsed time is always correct from timestamps
- No battery drain from background timers or `BGTaskScheduler`
- `TimelineView(.periodic(from:by:1))` handles the 1 Hz UI refresh declaratively
- `accessibilityReduceMotion` gracefully switches from animated to static transitions

---

## Class Diagram

```mermaid
classDiagram
    class MeetingModel {
        <<@Model>>
        +String meetingName
        +Date meetingStart
        +Date? meetingEnd
        +Double meetingLength
        +Double meetingCost
        +String meetingNotes
        +Bool isRunning
        +Date? pausedAt
        +Double totalPausedDuration
        +String meetingCurrencyCode
        +[MeetingParticipant] participants
        +liveElapsed: TimeInterval
        +endMeeting(convert:)
        +canAdd(participant:) Bool
    }

    class MeetingParticipant {
        <<@Model>>
        +String firstName
        +String lastName
        +Double hourlyRate
        +RateType rateType
        +ParticipantType participantType
        +String currencyCode
        +[MeetingModel] meetings
    }

    class RateType {
        <<enum>>
        hourly
        daily
    }

    class ParticipantType {
        <<enum>>
        human
        resource
    }

    class ExchangeRateService {
        <<@Observable @MainActor>>
        +[String: Double] rates
        +Bool isLoading
        +fetchRates() async
        +convert(amount, from, to) Double
    }

    MeetingModel "*" <--> "*" MeetingParticipant : many-to-many
    MeetingParticipant --> RateType
    MeetingParticipant --> ParticipantType
    MeetingModel ..> ExchangeRateService : currency conversion
```

---

## Platform Support

```mermaid
flowchart LR
    subgraph Apple["Apple Ecosystem"]
        direction TB

        subgraph iPhone["iPhone"]
            IS["NavigationStack"]
            IT["Compact layout"]
        end

        subgraph iPad["iPad / Mac"]
            PS["NavigationSplitView"]
            PT["Sidebar + Detail"]
        end

        subgraph Landscape["Landscape Mode"]
            LS["LiveBoard"]
            LT["Large cost display\nminimumScaleFactor"]
        end

        subgraph Watch["Apple Watch"]
            WS["Companion App"]
            WT["Glanceable cost"]
        end
    end

    iPhone ~~~ iPad
    iPad ~~~ Landscape
    Landscape ~~~ Watch

    style iPhone fill:#007AFF,color:#fff
    style iPad fill:#5856D6,color:#fff
    style Landscape fill:#FF9500,color:#fff
    style Watch fill:#FF2D55,color:#fff
```

| Platform | Navigation | Key Adaptation |
|---|---|---|
| **iPhone** | `NavigationStack` | Compact single-column layout |
| **iPad** | `NavigationSplitView` | Sidebar with meeting list, detail pane |
| **Mac** (Catalyst) | `NavigationSplitView` | Desktop-native sidebar experience |
| **Landscape** | LiveBoard | Large-format cost display with `minimumScaleFactor` |
| **Apple Watch** | Companion | Glanceable meeting cost on the wrist |

Platform detection uses `horizontalSizeClass` at runtime — one codebase, adaptive everywhere.

---

## Tech Stack

| Layer | Framework | Role |
|---|---|---|
| UI | **SwiftUI** | Declarative cross-platform interface |
| Data | **SwiftData** | Persistence with `@Model` macros |
| Sync | **CloudKit** | Transparent cross-device sync via SwiftData |
| Charts | **Swift Charts** | 5 chart types with accessibility descriptors |
| Observation | **Observation** | `@Observable` macro for reactive state |
| Networking | **URLSession** | `async/await` exchange rate fetch |
| Concurrency | **Swift Concurrency** | Swift 6.2 "Approachable Concurrency" — zero GCD |
| Testing | **Swift Testing** + **XCTest** | Unit + UI test suites |
| Localization | **.xcstrings** | 11 languages with plural rules |

**External dependencies: 0.** Every framework ships with Xcode.

---

## Highlights

### Timestamp-Based Timer
No `Timer`, no `DispatchSourceTimer`, no `BGTaskScheduler`. Elapsed time is pure date arithmetic (`Date.now - meetingStart - totalPausedDuration`), making the timer immune to app suspension. `TimelineView` provides declarative 1 Hz UI refresh.

### Resource Scheduling Constraint
Resources (rooms, projectors) are validated with a `#Predicate` query that checks for active meetings — a resource cannot join a second running meeting. This prevents double-booking at the data layer.

### Multi-Currency Lazy Conversion
Each participant stores their own `currencyCode` and `hourlyRate`. Conversion to the meeting's base currency happens at display time using live exchange rates from [open.er-api.com](https://open.er-api.com), with graceful degradation if the network is unavailable.

### Full Accessibility
Every interactive element carries `accessibilityLabel` and `accessibilityHint`. All five charts implement `AXChartDescriptorRepresentable` for VoiceOver. `accessibilityReduceMotion` disables animations and switches `numericText` transitions to `.identity`. Dynamic Type is supported via SwiftUI font styles.

### Cross-Platform Adaptive UI
A single `horizontalSizeClass` check at the navigation root switches between `NavigationSplitView` (iPad/Mac) and `NavigationStack` (iPhone). Landscape orientation triggers a dedicated LiveBoard with large-format cost display.

### CloudKit Sync
SwiftData's CloudKit integration provides transparent cross-device sync. Meetings, participants, and their many-to-many relationships replicate automatically.

### Zero Dependencies
The entire app is built with Apple-provided frameworks. No SPM packages, no CocoaPods, no Carthage — reducing build complexity, audit surface, and long-term maintenance.

---

## Testing

| Suite | Framework | Tests | Coverage |
|---|---|---|---|
| **Unit** | Swift Testing | 8 tests | Rate normalization, cost calculation, timer logic, resource conflict validation |
| **UI** | XCTest / XCUITest | 5 tests | Add/delete meeting, timer start/pause/stop, add participant |

Unit tests use an **in-memory SwiftData store** for isolation and speed.

```
swift test
```

---

## Requirements

| | Minimum |
|---|---|
| **iOS / iPadOS** | 18.0+ |
| **macOS** | 15.0+ |
| **watchOS** | 11.0+ |
| **Xcode** | 16.0+ |
| **Swift** | 6.2 |

---

## Getting Started

```bash
git clone https://github.com/arthurkahwa/meetingclock.git
cd meetingclock
open MeetCost.xcodeproj
```

Build and run on any simulator or device. No dependencies to install. No configuration needed.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

**Built with Swift and SwiftUI by [Arthur Kahwa](https://github.com/arthurkahwa)**

*Crafted with zero external dependencies. Every framework ships with Xcode.*

</div>
