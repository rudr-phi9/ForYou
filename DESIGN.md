# ✦ For You — Design Philosophy & UI/UX Specification

---

## 1. Core Philosophy: Zero-Noise, Intent-Driven Research

**"For You" exists for one reason: the user gets only what they asked for. Nothing more. No distractions.**

Every design decision in this application stems from a single principle: **respect the user's attention**. Unlike social media platforms, news aggregators, and recommendation engines that optimize for engagement and time-on-platform, For You optimizes for **time saved**. The user defines precisely what they care about, and the system delivers only high-quality, verified, research-grade content — then gets out of the way.

### The Five Pillars

| Pillar | Implementation |
|---|---|
| **User-Controlled Signal** | Tags define the entire content scope. Nothing leaks in that the user didn't ask for. |
| **AI as Gatekeeper** | Every item passes through a quality filter before reaching the feed. Memes, clickbait, listicles, and low-effort content are silently discarded. |
| **No Passive Consumption** | Every item in the feed is actionable — read it, save it, favorite it, or chat deeper. There is no infinite scroll dopamine loop. |
| **Depth Over Breadth** | The built-in chat lets users go deep on any single item rather than encouraging skimming across many. |
| **Respect for Attention** | Menu bar app, no Dock icon, no splash screen, no onboarding carousel, no "just one more" push. It appears when you want it and disappears when you don't. |

### What This App Must Never Do

- Never inject sponsored or promoted content
- Never reorder items by engagement metrics
- Never add infinite scroll or "load more" gamification
- Never send notifications designed to pull the user back (only notify for genuinely new high-value content)
- Never track usage patterns to manipulate feed ordering
- Never surface content the user didn't explicitly subscribe to via tags

---

## 2. Visual Design Language: Liquid Glass

The entire application is built on the **Liquid Glass** design system — a layered visual metaphor where every UI element looks like a pane of frosted glass floating over a slowly shifting fluid background. The deep blues and purples of the color palette bleed through the glass, creating a cohesive, living aesthetic.

### 2.1 Color Palette

| Token | Value | Role |
|---|---|---|
| **Liquid Blue** | `rgb(0.1, 0.3, 0.95)` | Primary accent — links, active states, sync button |
| **Liquid Purple** | `rgb(0.6, 0.1, 0.95)` | Secondary accent — gradient endpoints, bookmarks |
| **Neon Highlight** | `rgb(0.0, 0.9, 0.8)` | Tertiary accent — tags, links inside cards, action hover states. A cyan that pierces through purple glass. |
| **Gemini Blue Light** | `rgb(0.45, 0.55, 0.95)` | Subtle text highlights |

**Why these colors:** Standard blues and purples at typical saturations get washed out behind material blurs. These are intentionally over-saturated so they remain vivid after passing through `.ultraThinMaterial` and `.thinMaterial` layers.

### 2.2 The Three Glass Layers

Every glass element in the app is composed of three visual layers:

```
Layer 1 — The Blur          .background(.ultraThinMaterial)
Layer 2 — The Edge           .overlay(RoundedRectangle.stroke(glassEdge gradient))
Layer 3 — The Float          .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
```

**Layer 1: The Blur.** Apple's `.ultraThinMaterial` creates the frosted glass base, letting colors beneath bleed through at ~20% opacity.

**Layer 2: The Glass Edge.** A specular highlight stroke simulates light hitting the edge of physical glass. The gradient runs from `white @ 40%` at top-leading to `clear` in the center to `white @ 10%` at bottom-trailing, mimicking a single light source above-left.

**Layer 3: The Float.** A soft drop shadow (`0.15` opacity, 10pt radius, 5pt Y offset) lifts the element off the surface, reinforcing the physical glass metaphor.

### 2.3 The Fluid Background

Behind everything, three large blurred circles (`geminiBlue`, `geminiPurple`, `neonHighlight`) slowly pulse and drift using an 8-second `easeInOut` animation that repeats forever. This creates a living, breathing canvas that gives the app a sense of warmth and motion.

```
┌──────────────────────────────┐
│      ○ blue blob (200pt)     │  ← blur(60), opacity 0.6
│   ○ purple blob (180pt)      │  ← blur(55), opacity 0.5
│            ○ cyan (140pt)    │  ← blur(50), opacity 0.15
│                              │
│  All slowly offset ±50pt     │
│  over 8 seconds, forever     │
└──────────────────────────────┘
         ↓ covered by ↓
    Rectangle().fill(.thinMaterial)
```

The `.thinMaterial` rectangle on top subdues the blobs just enough that they provide ambient color without being distracting. The result feels like colored ink slowly swirling beneath frosted glass.

### 2.4 Gradients

| Name | Definition | Usage |
|---|---|---|
| `.gemini` | Blue → Purple, horizontal | Tag pills (selected), user chat bubbles, sparkle labels |
| `.geminiVertical` | Blue 15% → Purple 10%, vertical | Unused after glass redesign (retained for compatibility) |
| `.glassEdge` | white 40% → clear → white 10%, topLeading → bottomTrailing | Specular edge highlight on all glass elements |

---

## 3. App Flow & Screen-by-Screen Specification

### 3.0 Entry Point: The Menu Bar

**For You has no Dock icon.** It exists solely as a status bar item — a ✦ sparkle icon in the macOS menu bar. This is a deliberate design choice: the app should never demand attention. It waits.

| Interaction | Result |
|---|---|
| **Left-click** ✦ | Toggle the popover (feed) |
| **Right-click** ✦ | Context menu: Sync Now (⌘R), Preferences (⌘,), Quit (⌘Q) |

**The icon itself:** SF Symbol `sparkles`, 14pt medium weight. No badge count, no color changes, no attention-seeking animations. Always calm. Always available.

---

### 3.1 Screen 1: The Popover (Main Feed)

**Dimensions:** 400 × 580 px
**Background:** Fluid blob canvas + `.thinMaterial` overlay
**Purpose:** Show the user exactly what they asked for, sorted by recency, filterable by topic and importance.

```
┌──────────────────────────────────────────┐
│                                          │
│   For You          ⭐  🔖  📊  🔄  ⚙️  │  ← Zone A: Header
│                                          │
├──────────────────────────────────────────┤
│   [All] [#ML] [#Robotics] [#VLA]        │  ← Zone B: Tag Bar
├──────────────────────────────────────────┤
│                                          │
│   ┌──────────────────────────────────┐   │
│   │  📄 arXiv  ◉7.8    · 3h ago     │   │  ← Zone C: Content Cards
│   │                                  │   │     (scrollable)
│   │  Title of the Paper              │   │
│   │  #machine_learning               │   │
│   │                                  │   │
│   │  ✨ Summary (Textual Analysis)   │   │
│   │  "This paper proposes..."        │   │
│   │  • Key takeaway one              │   │
│   │  • Key takeaway two              │   │
│   │                                  │   │
│   │  🔗  ⭐  🔖  📋  💬            │   │  ← Action buttons
│   └──────────────────────────────────┘   │
│                                          │
│   ┌──────────────────────────────────┐   │
│   │  🌐 blog.example.com  ◉6.5      │   │
│   │  ...                             │   │
│   └──────────────────────────────────┘   │
│                                          │
└──────────────────────────────────────────┘
```

#### Zone A: Header Bar

A single horizontal row containing:

| Element | Behavior | Visual State |
|---|---|---|
| **"For You"** title | Static | `.title3`, `.bold` |
| **⭐ Favorites** | Toggle — filters feed to only favorited items | Yellow when active, `.secondary` when off |
| **🔖 Saved** | Toggle — filters feed to only bookmarked items | Purple when active, `.secondary` when off |
| **📊 Importance** | Dropdown menu: All / 4+ / 6+ / 7+ / 8+ / 9+ | Blue + shows threshold when active |
| **🔄 Sync** | Triggers manual sync. Spins continuously while syncing. | Blue always. Disabled during sync. |
| **⚙️ Settings** | Opens Settings sheet | `.secondary` always |

**Design note:** No hamburger menu. No hidden navigation. Every action is visible and one-click accessible. The header is never taller than one line.

#### Zone B: Tag Pill Bar

A horizontally scrollable row of **gel-drop pills** — one for "All" plus one per active tag.

**Unselected pill:**
- Background: `.ultraThinMaterial`
- Border: `white @ 20%` → `clear` gradient stroke, 0.5pt
- Text: `.secondary`
- Shadow: `black @ 8%`, 4pt radius, 2pt Y

**Selected pill:**
- Background: `.ultraThinMaterial` base + `geminiBlue 40%` → `geminiPurple 40%` gradient overlay
- Border: Full `.glassEdge` stroke, 1pt
- Text: `.white`, `.bold`
- Shadow: Same as unselected

**Hover:** Scale to 1.05× over 150ms `easeInOut`.

**Tap behavior:** Tapping a pill filters the feed to that tag. Tapping the same pill again deselects it (returns to "All"). Only one tag can be selected at a time — this is a filter, not multi-select. The "All" pill resets.

#### Zone C: Content Cards

Each research item is rendered as a `ContentCardView` using the Liquid Glass card modifier (`.geminiCard()`). Cards are stacked in a `LazyVStack` with 8pt spacing, inside a `ScrollView`.

**Card anatomy (top to bottom):**

1. **Source Row:** Source icon (SF Symbol) + source name + **Glowing Orb** (importance) + relative timestamp
2. **Preview Image:** If available — hero image or YouTube thumbnail, `maxHeight: 140`, clipped to rounded rect. For papers with no image, a subtle `doc.text.fill` icon on glass background.
3. **Title:** `.subheadline, .semibold`, max 3 lines.
4. **Tags:** `#tag_name` in neon cyan (`.neonHighlight`).
5. **AI Summary Block:** Nested glass panel containing:
   - Label: "✨ Summary (Textual Analysis)" or "(Visual/Audio Analysis)" in `.gemini` gradient
   - Summary text: `.caption`, `.secondary`, max 6 lines
   - Key takeaways: Bulleted list, neon cyan bullets, `.secondary` text, max 2 lines each
6. **Action Buttons:** Row of `GlassActionButton` instances (see §4.3)

**Card hover effect:** On mouse-over, the card scales to 1.02× and the glass edge stroke opacity increases from 0.6 to 1.0, creating a subtle "light up" effect. Transition: 200ms `easeInOut`.

**Card tap:** Opens the Detail View as a sheet (not navigation push).

#### Empty States

The feed has three distinct empty states, each with a centered layout:

| Condition | Icon | Message | Action |
|---|---|---|---|
| No tags added | `sparkles` | "Add some research topics in Settings to get started." | "Open Settings" button |
| No API key | `sparkles` | "Add your AI API key in Settings." | "Open Settings" button |
| Tags + key, no items | `sparkles` | "Tap Sync to fetch the latest research." | "Sync Now" button |
| Importance filter too high | `chart.bar.fill` | "No items with importance X+ yet" | "Show all" link |
| Favorites/Saved empty | `star` / `bookmark` | "No favorites/saved items yet" | (none) |

---

### 3.2 Screen 2: Detail View (Expanded Item)

**Dimensions:** 500 × 600 px sheet
**Background:** Fluid blob canvas + `.thinMaterial` overlay (same as popover)
**Purpose:** Full, uninterrupted reading of a single item's AI-generated analysis.

```
┌──────────────────────────────────────────────┐
│  ✕                        ◉8.2   ⭐   🔖    │  ← Top bar
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │          [Hero Image]                │    │  ← Gradient-faded
│  │             ↓ fades to clear ↓       │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  🌐 arXiv · 3 hours ago                     │
│                                              │
│  Title of the Research Paper                 │
│  Authors: Alice, Bob, Charlie                │
│  #machine_learning  #reinforcement_learning  │
│                                              │
│  ◉ 8.2 / 10 · Avg h-index: 42               │
│                                              │
│  ┌──────────────────────────────────────┐    │
│  │  ✨ Summary (Textual Analysis)       │    │  ← Glass summary panel
│  │                                      │    │
│  │  Full multi-paragraph summary...     │    │
│  │                                      │    │
│  │  Key Takeaways                       │    │
│  │  • First finding                     │    │
│  │  • Second finding                    │    │
│  │  • Third finding                     │    │
│  └──────────────────────────────────────┘    │
│                                              │
│  [ Open Original ]  [ Copy Link ]  [ Chat ]  │
│                                              │
└──────────────────────────────────────────────┘
```

#### Hero Image Treatment

If the item has a hero image or YouTube thumbnail, it's placed at the very top of the scroll content, **edge-to-edge** (no padding), with `maxHeight: 200`. A `LinearGradient` mask fades the image from solid at the top to transparent at the bottom, so it bleeds seamlessly into the content below. This eliminates the hard boundary between image and text.

```swift
.mask(LinearGradient(
    colors: [.white, .white, .white.opacity(0)],
    startPoint: .top, endPoint: .bottom
))
```

#### Content Layout

All content below the hero image is padded 20pt on all sides and uses a `VStack(alignment: .leading, spacing: 16)`.

| Element | Font | Color |
|---|---|---|
| Source icon + name | `.caption` | Neon cyan icon, `.secondary` text |
| Timestamp | `.caption2` | `.tertiary` |
| Title | `.title3, .bold` | `.primary` |
| Authors | `.caption` | `.secondary` |
| Tags | `.caption2, .medium` | `.neonHighlight` |
| Importance | GlowingOrb + ".1f / 10" | Orb color + `.secondary` text |
| Author metric | `.caption` | `.secondary` |

#### Summary Glass Panel

The summary section is wrapped in its own glass panel:
- Background: `.ultraThinMaterial`
- Corner radius: 12pt
- Stroke: `.glassEdge`, 0.5pt
- Padding: 12pt internal

Summary text uses `.body` font with `.secondary` foreground. Key takeaway bullets use neon cyan dot color.

#### Action Buttons

Three buttons at the bottom:

| Button | Style | Color | Action |
|---|---|---|---|
| **Open Original** | `.borderedProminent` | `.geminiBlue` | Opens URL in browser |
| **Copy Link** | `.bordered` | System | Copies URL to clipboard |
| **Chat** | `.bordered` | System | Opens ChatView sheet |

---

### 3.3 Screen 3: Chat View (Conversational Deep Dive)

**Dimensions:** 420 × 500 px sheet
**Background:** Fluid blob canvas + `.thinMaterial` overlay
**Purpose:** Let the user ask follow-up questions about any research item using Gemini AI — with full context of the item's content, summary, and takeaways.

```
┌──────────────────────────────────────────┐
│  ‹  Chat                                 │
│     [Paper Notes] Title of item...       │  ← Header
├──────────────────────────────────────────┤
│                                          │
│           ┌──────────────────────┐       │
│           │ What is this about?  │       │  ← User bubble (gradient)
│           └──────────────────────┘       │
│                                          │
│  ┌──────────────────────────┐            │
│  │ This paper proposes a    │            │  ← Assistant bubble (glass)
│  │ novel architecture for...│            │
│  └──────────────────────────┘            │
│                                          │
│           ┌──────────────────────┐       │
│           │ Explain in detail    │       │
│           └──────────────────────┘       │
│                                          │
│  ┌──────────────────────────┐            │
│  │ ●  ●  ●                 │            │  ← Thinking indicator
│  └──────────────────────────┘            │
│                                          │
├──────────────────────────────────────────┤
│  Ask about this paper…          ⬆       │  ← Input bar
└──────────────────────────────────────────┘
```

#### Message Bubbles

**User messages (right-aligned):**
- Background: `LinearGradient.gemini` (blue → purple)
- Text: `.white`
- Corner radius: 14pt
- Shadow: `black @ 8%`, 4pt radius

**Assistant messages (left-aligned):**
- Background: `.ultraThinMaterial`
- Border: `.glassEdge` stroke, 0.5pt
- Text: `.primary`, Markdown rendered via `AttributedString(markdown:)` with `.inlineOnlyPreservingWhitespace`
- Corner radius: 14pt
- Shadow: `black @ 8%`, 4pt radius

Both bubble types have `Spacer(minLength: 60)` on the opposite side to prevent full-width messages.

#### Thinking Indicator

Three small circles (8pt) filled with `LinearGradient.gemini`, animating with staggered breathing:
- Scale: 0.4× → 1.0×
- Opacity: 0.3 → 1.0
- Duration: 600ms per cycle, each dot delayed by 200ms
- Background: Glass bubble (same style as assistant messages)

#### Typewriter Animation

When a response arrives from the API, the full text is received first, then revealed character-by-character in the UI:
- Speed: ~8ms per character, ~2ms for whitespace (gives a natural reading rhythm)
- Yield: Every 3 characters, allow UI update
- Auto-scroll triggers once when the message first appears, then stops — the user can scroll freely during the typewriter animation

#### Message Persistence

All messages are stored in SwiftData as `ChatMessage` objects keyed by `itemURL`. When the user re-opens chat for the same item, the full conversation history loads immediately. The conversation history is also sent to Gemini as context for each new message, enabling genuine multi-turn dialogue.

#### On-Demand Content Fetching

If the item's `rawTextContent` is empty when chat opens (common for blogs and YouTube), the system automatically scrapes the original URL via `WebScraperService` before sending the first message. The scraped content is cached back on the item for future chats.

#### System Prompt Design

The chat system prompt instructs the model to:
- Be a knowledgeable expert who combines the provided item context with its own deep knowledge
- Never refuse by saying "I only have a summary" — instead, expand using general knowledge
- Format responses with Markdown (bold, bullets, code blocks) for readability

---

### 3.4 Screen 4: Settings (Preferences)

**Dimensions:** 400 × 440 px (minimum), sheet presentation
**Background:** `.ultraThinMaterial`
**Purpose:** Configure tags, API keys, and sync interval. Every setting is immediately applied. No "Apply" or "OK" button.

```
┌──────────────────────────────────────────┐
│  Manage Interests & Topics               │
├──────────────────────────────────────────┤
│                                          │
│  🏷 Active Topics                        │  ← Section A
│  ┌──────────────────────────────────┐    │
│  │ ● Machine Learning    [ON]  ✕   │    │
│  │ ○ Quantum Computing   [OFF] ✕   │    │
│  │ ● Robotics            [ON]  ✕   │    │
│  └──────────────────────────────────┘    │
│                                          │
│  ┌────────────────────────┐ [Add Tag]    │  ← Section B
│  │ Enter a research topic │              │
│  └────────────────────────┘              │
│                                          │
│  🔑 AI API Key                           │  ← Section C
│  ✅ API key configured 🔒   [Unlock]     │
│                                          │
│  ▶️ YouTube API Key (optional)           │  ← Section D
│  ✅ YouTube key configured 🔒  [Unlock]  │
│                                          │
│  🕐 Sync Interval                        │  ← Section E
│  ──────●──────────── 2.0 hours           │
│                                          │
└──────────────────────────────────────────┘
```

#### Section A: Active Topics

Each tag is displayed as a row with:
- **Status dot:** Gemini gradient circle (8pt) if active, gray if inactive
- **Tag name:** `.body` font
- **Toggle:** Native macOS switch (`.controlSize(.small)`)
- **Delete button:** Red `xmark.circle.fill` — immediately deletes the tag from SwiftData

Tags are sorted by creation date (newest first).

#### Section B: Add New Tag

A text field + "Add Tag" button. Pressing Return submits. Duplicates (case-insensitive) are silently ignored. The button is disabled while the field is empty.

#### Sections C & D: API Keys (Touch ID Protected)

Both API key sections follow the same UX pattern:

**Locked state (key exists, not unlocked):**
- Shows "✅ API key configured" with a green checkmark shield
- "🔒 Unlock" button on the right
- Tapping Unlock triggers `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` — Touch ID prompt or system password fallback

**Unlocked state (no key, or after successful authentication):**
- Shows a `SecureField` with current key value
- "Save" button (`.borderedProminent`, geminiBlue tint)
- After saving: flashes "✅ key saved!" for 2 seconds, then re-locks

**Rationale:** API keys are sensitive credentials. Requiring biometric auth to view/edit them prevents shoulder-surfing and accidental exposure. Keys are stored in UserDefaults with automatic whitespace/comma trimming on both read and write.

#### Section E: Sync Interval

A native `Slider` from 1.0 to 6.0 hours, 0.5h steps. Current value displayed as text. Changes apply immediately to `SettingsManager`.

---

## 4. Reusable Component Specifications

### 4.1 The Glowing Orb (`GlowingOrb`)

Replaces traditional flat importance badges. A score number floating on top of a radial gradient glow that acts like an LED embedded in glass.

**Construction:**
```
ZStack {
    Circle with RadialGradient (orbColor @ 45% → transparent)
        32 × 32pt, blur(6)           ← The glow
    Text(score) .system(11pt, bold, rounded)
        .primary @ 85%                ← The number
}
```

**Color mapping:**

| Score | Orb Color | Semantic |
|---|---|---|
| 8.0 – 10.0 | Green | High importance |
| 6.0 – 7.9 | Liquid Blue | Medium-high |
| 4.0 – 5.9 | Orange | Medium |
| 0.0 – 3.9 | Gray | Low importance |

### 4.2 Tag Pill (`TagPillView`)

Gel-drop capsule buttons used in the tag filter bar. See §3.1 Zone B for full spec.

### 4.3 Glass Action Button (`GlassActionButton`)

Interactive icon buttons used in content cards and the detail view top bar. Each button has three visual states:

| State | Icon Color | Background |
|---|---|---|
| **Default (inactive)** | `inactiveColor` (usually `.secondary`) | None (transparent) |
| **Active** (e.g., favorited) | `activeColor` (e.g., `.yellow`) | None |
| **Hovered** | `.neonHighlight` (cyan) | Frosted glass circle (`.ultraThinMaterial`) with `.glassEdge` stroke |

The hover glass circle appears/disappears over 150ms `easeInOut`. This micro-interaction reinforces the glass metaphor — hovering "activates" a tiny lens behind the icon.

### 4.4 Liquid Glass Card (`.geminiCard()` modifier)

Applied to all content cards. See §2.2 for the three-layer construction. Additionally includes:

- **Corner radius:** 16pt (increased from original 10pt for the glass aesthetic)
- **Hover scale:** 1.02× with 200ms `easeInOut`
- **Hover edge brightness:** Glass edge stroke opacity increases from 0.6 → 1.0

---

## 5. Interaction Patterns

### 5.1 Micro-Interactions

| Element | Trigger | Animation |
|---|---|---|
| Content card | Hover | Scale 1.02×, edge stroke brightens. 200ms easeInOut. |
| Tag pill | Hover | Scale 1.05×. 150ms easeInOut. |
| Action button | Hover | Neon cyan color + glass circle background. 150ms easeInOut. |
| Sync button | Sync active | Continuous 360° rotation, 1s linear, infinite. |
| Thinking dots | Waiting for AI | Staggered breathing (scale 0.4→1.0, opacity 0.3→1.0), 600ms cycles. |
| Typewriter text | Response received | Character-by-character reveal, ~8ms/char. |
| Fluid blobs | Always | Slow 8-second position drift, infinite autoreverses. |

### 5.2 Navigation Model

The app uses a **flat, sheet-based navigation** model. There is no navigation stack, no sidebar, no tabs.

```
Menu Bar Icon
    │
    ├─ Left-click → Popover (Feed)
    │                   │
    │                   ├─ Tap card → Detail View (sheet)
    │                   │                │
    │                   │                └─ Chat button → Chat View (sheet)
    │                   │
    │                   ├─ Chat button on card → Chat View (sheet)
    │                   │
    │                   └─ Settings gear → Settings (sheet)
    │
    └─ Right-click → Context Menu
                        ├─ Sync Now
                        ├─ Preferences → Settings (sheet)
                        └─ Quit
```

Every destination is a **sheet** that can be dismissed independently. There is no "back button" concept except in the Chat view (which has a `‹` chevron for dismissal). This flat structure means the user is never more than one tap away from the feed.

### 5.3 Data Flow: From Source to Screen

```
User defines tags
       │
       ▼
GatheringService.performGathering()
       │
       ├─ withTaskGroup (all tags in parallel, max 10)
       │      │
       │      ├─ async let arXiv      → ArXivService.search()
       │      ├─ async let blogs      → GoogleSearchService.search() (DuckDuckGo)
       │      └─ async let youtube    → YouTubeService.search()
       │
       ▼
Items collected as FetchedItem (Sendable value type)
       │
       ▼
Deduplicate by URL against existing SwiftData items
       │
       ▼
Insert into SwiftData (mainContext, @MainActor)
Items appear in feed IMMEDIATELY (insert-first architecture)
       │
       ▼
enrichContent() — SINGLE Gemini API call per item:
       │
       ├─ QUALITY check → LOW? → item.isDiscarded = true (never shown)
       ├─ 4-sentence summary
       ├─ 3 key takeaways
       ├─ Importance score (0–10)
       └─ Author metric (h-index estimate for papers)
       │
       ▼
Item updated in SwiftData → UI reactively refreshes
```

**Key design decisions in this pipeline:**
1. **Insert-first:** Items appear before AI processing. The user sees titles instantly; summaries fill in over seconds.
2. **Single API call:** Summary, scoring, takeaways, and quality filtering are all done in one prompt. This halves API costs compared to separate calls.
3. **Quality gating:** Low-quality content (memes, clickbait, listicles, promos) is discarded in the same call, before it ever reaches the UI.

---

## 6. Typography

All text uses the **system font** (SF Pro on macOS).

| Context | Style | Weight | Size Class |
|---|---|---|---|
| App title ("For You") | `.title3` | `.bold` | ~17pt |
| Card titles | `.subheadline` | `.semibold` | ~13pt |
| Detail view title | `.title3` | `.bold` | ~17pt |
| Summary label | `.caption2` | `.semibold` | ~10pt |
| Summary body (card) | `.caption` | `.regular` | ~11pt |
| Summary body (detail) | `.body` | `.regular` | ~13pt |
| Tags | `.caption2` | `.medium` | ~10pt |
| Timestamps | `.caption2` | `.regular` | ~10pt |
| Source names | `.caption` | `.regular` | ~11pt |
| Chat messages | `.body` | `.regular` | ~13pt |
| Importance score | `.system(11)` | `.bold` | 11pt rounded |
| Settings headers | `.headline` | `.bold` | ~15pt |
| Chat header | `.headline` | `.bold` | ~15pt |

---

## 7. Accessibility Notes

- All interactive elements have `.help()` tooltips for VoiceOver and hover hints
- All SF Symbols include `accessibilityDescription` where contextually important
- Text uses semantic foreground styles (`.primary`, `.secondary`, `.tertiary`) which automatically adapt to light/dark mode and accessibility settings
- Materials (`.ultraThinMaterial`, `.thinMaterial`) automatically adjust for Increase Contrast accessibility setting
- No color is the sole indicator of state — icons change shape (filled vs. outline) alongside color changes (e.g., `star` vs. `star.fill`)

---

## 8. Performance Considerations

- **LazyVStack** for feed rendering — only visible cards are in memory
- **AsyncImage** for remote image loading — no manual caching needed
- Image thumbnails are clipped with `aspectRatio(.fill)` and `maxHeight` rather than downloading resized versions
- Fluid background animation uses `blur()` on simple `Circle()` shapes — GPU-composited, no CPU overhead
- Typewriter animation yields every 3 characters to avoid blocking the main thread
- SwiftData `@Query` with `#Predicate` ensures the database does the filtering, not in-memory iteration

---

## 9. Version History of Design Decisions

| Version | Change | Rationale |
|---|---|---|
| v1 | Flat `.quaternary` backgrounds, solid gradient pills | Initial prototype |
| v2 (Liquid Glass) | `.ultraThinMaterial` everywhere, glass edge strokes, fluid blob backdrop, GlowingOrb, GlassActionButton, gel-drop pills | Cohesive premium aesthetic that reinforces the "floating glass" hardware metaphor |
| v2.1 | Reduced GlowingOrb opacity (100% → 45%), smaller radius (20→16), blur (8→6) | Orb was too visually dominant, distracting from content |
| v2.2 | Added neon cyan (`Color.neonHighlight`) for tags and action hovers | Tags were indistinct; cyan provides clear visual separation against blue/purple glass |
| v3 (Chat) | Added ChatView with Markdown rendering, typewriter animation, thinking indicator | Depth-over-breadth principle — let users go deep on any single item |
| v3.1 | Chat system prompt rewritten to never refuse; on-demand web scraping for content | Model was saying "I don't have enough data" — antithetical to the depth principle |
