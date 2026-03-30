<p align="center">
  <img src="https://developer.apple.com/sf-symbols/" width="0" height="0" />
  <h1 align="center">✦ For You</h1>
  <p align="center"><strong>AI-Powered Research Aggregator for macOS</strong></p>
  <p align="center">
    A native macOS menu bar application that autonomously discovers, summarizes, and scores research content from arXiv, technical blogs, and YouTube — powered by Google Gemini 2.5 Pro.
  </p>
</p>

---

## Overview

**For You** lives in your menu bar and continuously monitors research topics you care about. It pulls papers from arXiv, finds technical blog posts via DuckDuckGo, and (optionally) surfaces YouTube lectures — then uses Gemini AI to generate concise summaries, extract key takeaways, and score each item by importance. No Dock icon, no window clutter — just a sparkle ✦ in your menu bar.

**Built with:** Swift · SwiftUI · SwiftData · Google Generative AI SDK · macOS 14+

---

## Features

### Research Aggregation
- **arXiv Papers** — Fetches the latest papers from arXiv's Atom API sorted by submission date
- **Technical Blogs** — Discovers blog posts, tutorials, and engineering articles via DuckDuckGo HTML search (no API key needed)
- **YouTube Talks** — Searches for lectures, conference talks, and keynotes via YouTube Data API v3 (optional, requires separate API key)
- **Automatic Deduplication** — Same URL never appears twice in your feed
- **Domain Exclusion** — Pre-configured blocklist filters out news outlets (CNN, BBC, Reuters, NYT, etc.)

### AI-Powered Intelligence
- **Gemini 2.5 Pro Summarization** — Every item gets a 4-sentence summary tailored to its content type (paper vs. blog vs. talk)
- **Key Takeaways** — 3 bullet-point takeaways extracted from each piece of content
- **Importance Scoring (0–10)** — AI estimates author credibility (h-index for papers), content quality, and relevance to your tags
- **Content Classification** — Distinguishes research from general news to keep your feed focused
- **Fallback Web Scraping** — If raw text isn't available, scrapes the URL to extract readable content for summarization

### Feed Management
- **Tag-Based Organization** — Create unlimited research topics (e.g., "Machine Learning", "Quantum Computing")
- **Three Feed Filters** — Switch between All, Favorites (⭐), and Saved (🔖) with one click
- **Per-Tag Filtering** — Tap a tag pill to see only items matching that topic
- **Favorite & Bookmark** — Star items you love, bookmark items to read later
- **Open in Browser** — Jump directly to the original source
- **Copy Link** — One-click clipboard copy
- **Detail View** — Tap any card to see the full expanded summary, all takeaways, author list, and importance metrics

### Background Sync
- **Automatic Sync Loop** — Configurable interval from 30 minutes to 6 hours (default: 2 hours)
- **Manual Sync** — Click the sync button or right-click → "Sync Now"
- **Insert-First Architecture** — Items appear in your feed immediately, then get AI-enriched in the background
- **Batch Summarization** — Opening the popover triggers summarization of any pending items

### Security & Notifications
- **Touch ID Protection** — API key is locked behind biometric authentication (Touch ID or system password)
- **Native macOS Notifications** — Get notified when new high-value content appears
- **Notification Deep Link** — Tap a notification to jump directly to that item in your feed

---

## Architecture

```
For You
├── App Layer
│   ├── GeminiResearchApp.swift     @main entry, Settings scene
│   └── AppDelegate.swift           Menu bar setup, popover, lifecycle
│
├── Models
│   ├── Tag.swift                   SwiftData model for research topics
│   ├── ResearchItem.swift          SwiftData model for feed items
│   ├── AppState.swift              Observable shared UI state
│   └── ContentType.swift           Paper / Blog / Talk / Unknown enum
│
├── Services
│   ├── GeminiService.swift         Google Generative AI SDK wrapper
│   ├── GatheringService.swift      Background sync orchestrator
│   ├── ArXivService.swift          arXiv Atom API client + XML parser
│   ├── GoogleSearchService.swift   DuckDuckGo HTML scraper
│   ├── YouTubeService.swift        YouTube Data API v3 client
│   ├── WebScraperService.swift     URL text extraction + og:image
│   ├── ImportanceScorer.swift      AI-driven 0–10 scoring
│   └── NotificationService.swift   UNUserNotificationCenter manager
│
├── Views
│   ├── PopoverView.swift           Main feed (header, tag bar, cards)
│   ├── ContentCardView.swift       Individual feed item card
│   ├── DetailView.swift            Expanded item sheet
│   ├── TagsSettingsView.swift      Preferences (tags, API key, sync)
│   └── TagPillView.swift           Reusable filter pill component
│
├── Theme
│   └── GeminiTheme.swift           Colors, gradients, card modifiers
│
└── Utilities
    └── SettingsManager.swift        UserDefaults-backed preferences
```

---

## UI Layers

### Menu Bar Icon
A **sparkle (✦)** icon sits in the macOS menu bar. Left-click opens the popover; right-click shows a context menu:

| Action | Shortcut |
|---|---|
| Sync Now | ⌘R |
| Preferences… | ⌘, |
| Quit For You | ⌘Q |

### Popover (400 × 580 px)

The main interface drops down from the menu bar:

```
┌─────────────────────────────────────┐
│  For You           ⭐ 🔖 🔄 ⚙️     │  ← Header with filter + action icons
├─────────────────────────────────────┤
│  [All] [ML] [Quantum] [Robotics]   │  ← Horizontal tag pill bar
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐    │
│  │ 📄 arXiv     8.2  · 2h ago │    │  ← Content card
│  │                             │    │
│  │ Title of the Paper          │    │
│  │ #machinelearning            │    │
│  │                             │    │
│  │ ✨ AI Summary               │    │
│  │ "This paper introduces..." │    │
│  │ • Key takeaway one          │    │
│  │ • Key takeaway two          │    │
│  │                             │    │
│  │ 🔗  ⭐  🔖  📋             │    │  ← Action buttons
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │ 🌐 blog.example.com   6.5  │    │  ← Another card
│  │ ...                         │    │
│  └─────────────────────────────┘    │
└─────────────────────────────────────┘
```

### Detail View (500 × 600 px sheet)

Tap any card to open the full detail:

```
┌──────────────────────────────────────────┐
│  ✕                    8.2  ⭐  🔖        │  ← Close + importance + actions
├──────────────────────────────────────────┤
│  📄 arXiv · March 28, 2026               │
│                                          │
│  [Hero Image]                            │
│                                          │
│  Title of the Research Paper             │
│  Authors: Alice, Bob, Charlie            │
│  #machinelearning                        │
│                                          │
│  Importance: 8.2 / 10                    │
│  Author Metric: Avg h-index: 42          │
│                                          │
│  ── Summary ──                           │
│  Full multi-paragraph AI summary...      │
│                                          │
│  ── Key Takeaways ──                     │
│  • First important finding               │
│  • Second important finding              │
│  • Third important finding               │
│                                          │
│  [ Open Original ]  [ Copy Link ]        │
└──────────────────────────────────────────┘
```

### Settings / Preferences Window (400 × 440 px)

Accessible via ⌘, or the gear icon:

```
┌──────────────────────────────────────────┐
│  Manage Interests & Topics               │
├──────────────────────────────────────────┤
│  Active Topics                           │
│  ● Machine Learning        [ON]  ✕      │
│  ○ Quantum Computing       [OFF] ✕      │
│  ● Robotics                [ON]  ✕      │
│                                          │
│  ┌────────────────────────┐ [Add Tag]    │
│  │ Enter a research topic │              │
│  └────────────────────────┘              │
├──────────────────────────────────────────┤
│  AI API Key                              │
│  ┌────────────────────────┐              │
│  │ API key configured 🔒  │ [Unlock]     │
│  └────────────────────────┘              │
│  Get key → aistudio.google.com           │
├──────────────────────────────────────────┤
│  Sync Interval                           │
│  ──────●──────────── 2.0 hours           │
└──────────────────────────────────────────┘
```

---

## Design Theme

The app uses a cohesive **blue-purple gradient** design language throughout:

| Token | Value | Usage |
|---|---|---|
| `geminiBlue` | `rgb(0.25, 0.35, 0.85)` | Primary accent, links, active states |
| `geminiPurple` | `rgb(0.55, 0.25, 0.85)` | Secondary accent, gradient endpoints |
| `geminiBlueLight` | `rgb(0.45, 0.55, 0.95)` | Lighter variant for subtle highlights |
| `gemini` gradient | Blue → Purple (horizontal) | Tag pills, active states, branding |
| `geminiVertical` gradient | Blue 15% → Purple 10% (vertical) | Summary block backgrounds |

### Card Styling

All content cards use the `.geminiCard()` modifier:
- **Background:** `.ultraThinMaterial` (frosted glass effect)
- **Corner Radius:** 10pt
- **Padding:** 12pt internal
- **Border:** 0.5pt with system separator color

### Importance Badge Colors

| Score Range | Color | Meaning |
|---|---|---|
| 8.0 – 10.0 | 🟢 Green | High importance |
| 6.0 – 7.9 | 🔵 Blue | Medium-high |
| 4.0 – 5.9 | 🟠 Orange | Medium |
| 0.0 – 3.9 | ⚪ Gray | Low importance |

### Typography
- All text uses the system font (SF Pro)
- Titles: `.subheadline` weight `.semibold`
- Body: `.caption` / `.caption2`
- Tags: `.caption2` in `geminiBlue`
- Icons: SF Symbols throughout (sparkles, doc.text, globe, play.rectangle, star, bookmark, etc.)

---

## Getting Started

### Prerequisites

- **macOS 14.0** (Sonoma) or later
- **Xcode 15+** with Swift 5.9
- **Homebrew** (for XcodeGen)
- A **Google Gemini API key** — free at [aistudio.google.com/apikey](https://aistudio.google.com/apikey)

### Installation

```bash
# 1. Clone and enter the project
cd /path/to/GeminiResearch

# 2. Run the setup script
chmod +x setup.sh
./setup.sh

# 3. Wait for Swift Package Manager to resolve GoogleGenerativeAI
# 4. Press ⌘R in Xcode to build and run
```

Or manually:

```bash
# Install XcodeGen
brew install xcodegen

# Generate Xcode project from project.yml
xcodegen generate

# Resolve SPM packages
xcodebuild -resolvePackageDependencies -scheme GeminiResearch

# Open in Xcode
open GeminiResearch.xcodeproj
```

### First Launch

1. The app appears as a **✦ sparkle icon** in your menu bar (no Dock icon)
2. **Left-click** the icon to open the feed popover
3. Click the **⚙️ gear icon** to open Settings
4. **Add your Gemini API key** — paste it and click Save
5. **Add research topics** — type a topic (e.g., "Machine Learning") and click Add Tag
6. Click the **🔄 sync button** or right-click → Sync Now
7. Papers and blogs will start appearing in your feed within seconds

### Configuration

| Setting | Default | Range | Description |
|---|---|---|---|
| API Key | (empty) | — | Google Gemini API key for AI features |
| Sync Interval | 2 hours | 0.5–6 hours | How often the app checks for new content |
| Tags | (none) | Unlimited | Research topics to monitor |
| Domain Exclusions | 15 news sites | Hardcoded | URLs containing these domains are filtered out |

---

## Data Sources

| Source | Method | Auth Required | Content Type |
|---|---|---|---|
| **arXiv** | Atom API | None | Research papers |
| **DuckDuckGo** | HTML scraping | None | Blog posts & tutorials |
| **YouTube** | Data API v3 | YouTube API key | Talks & lectures |

---

## Tech Stack

| Component | Technology |
|---|---|
| Language | Swift 5.9 |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData (SQLite-backed) |
| AI Engine | Google Generative AI SDK (`gemini-2.5-pro`) |
| Package Manager | Swift Package Manager via XcodeGen |
| Notifications | UNUserNotificationCenter |
| Authentication | LocalAuthentication (Touch ID) |
| Networking | URLSession (async/await) |
| XML Parsing | Foundation XMLParser |
| Target | macOS 14.0+ (Sonoma) |
| App Type | LSUIElement (menu bar only) |

---

## Sandbox Permissions

| Permission | Purpose |
|---|---|
| `app-sandbox` | Runs in macOS sandbox |
| `network.client` | HTTP/HTTPS for arXiv, DuckDuckGo, Gemini, YouTube APIs |
| `mach-lookup: com.apple.UNCUserNotification` | Deliver native notifications |

---

## License

This project is for personal use.
