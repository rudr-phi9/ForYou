import SwiftUI
import SwiftData

// MARK: - Scroll Offset PreferenceKey

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Chat window for asking questions about a specific research item.
/// Persists messages via SwiftData keyed on item URL.
struct ChatView: View {
    let item: ResearchItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false
    @State private var streamingMessageId: UUID? = nil
    @State private var streamingDisplayText = ""
    @State private var userScrolledUp = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack(spacing: 8) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Chat")
                        .font(.system(.headline, weight: .bold))
                    Text(item.title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            // MARK: - Messages
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    messageListContent
                }
                .coordinateSpace(name: "chatScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                    let atBottom = maxY < 520
                    if !atBottom && streamingMessageId != nil {
                        userScrolledUp = true
                    }
                }
                .onChange(of: messages.count) { _, _ in
                    userScrolledUp = false
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isThinking) { _, _ in
                    userScrolledUp = false
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: streamingDisplayText) { _, _ in
                    guard !userScrolledUp, let id = streamingMessageId else { return }
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }

            Divider()

            // MARK: - Input Bar
            HStack(spacing: 8) {
                TextField("Ask about this paper…", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .onSubmit { sendMessage() }

                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? AnyShapeStyle(.secondary)
                                : AnyShapeStyle(LinearGradient.gemini)
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 420, height: 500)
        .background {
            ZStack {
                Color.clear
                FluidBackground()
                Rectangle().fill(.thinMaterial)
            }
        }
        .onAppear { loadHistory() }
    }

    // MARK: - Actions

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                if isThinking {
                    proxy.scrollTo("thinking", anchor: .bottom)
                } else if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Message List (extracted to reduce type-check complexity)

    private var messageListContent: some View {
        LazyVStack(alignment: .leading, spacing: 10) {
            ForEach(messages) { msg in
                ChatBubble(
                    message: msg,
                    streamingText: msg.id == streamingMessageId ? streamingDisplayText : nil
                )
                .id(msg.id)
            }

            if isThinking {
                ThinkingIndicator()
                    .id("thinking")
            }

            Color.clear
                .frame(height: 1)
                .id("bottom")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: ScrollOffsetKey.self,
                    value: geo.frame(in: .named("chatScroll")).maxY
                )
            }
        )
    }

    private func loadHistory() {
        let url = item.url
        let descriptor = FetchDescriptor<ChatMessage>(
            predicate: #Predicate { $0.itemURL == url },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        messages = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMsg = ChatMessage(itemURL: item.url, role: "user", content: text)
        modelContext.insert(userMsg)
        messages.append(userMsg)
        inputText = ""
        isThinking = true

        let history = messages.map { (role: $0.role, content: $0.content) }
        let itemTitle = item.title
        let itemSummary = item.geminiSummary
        let itemTakeaways = item.keyTakeaways
        var itemContent = item.rawTextContent

        Task {
            do {
                // Fetch content on-demand if missing
                if (itemContent ?? "").isEmpty, let url = URL(string: item.url) {
                    let scraped = try? await WebScraperService.shared.scrape(url: url)
                    itemContent = scraped?.textContent
                    // Cache it back on the item for future chats
                    await MainActor.run {
                        item.rawTextContent = itemContent
                    }
                }

                let response = try await GeminiService.shared.chat(
                    itemTitle: itemTitle,
                    itemSummary: itemSummary,
                    itemTakeaways: itemTakeaways,
                    itemContent: itemContent,
                    history: history,
                    userMessage: text
                )

                let assistantMsg = ChatMessage(itemURL: item.url, role: "assistant", content: response)
                modelContext.insert(assistantMsg)
                messages.append(assistantMsg)
                isThinking = false

                // Typewriter animation: reveal character by character
                streamingMessageId = assistantMsg.id
                streamingDisplayText = ""
                let fullText = response
                for (i, char) in fullText.enumerated() {
                    streamingDisplayText.append(char)
                    // Variable speed: faster for spaces/punctuation
                    let delay: UInt64 = char.isWhitespace ? 2_000_000 : 8_000_000
                    if i % 3 == 0 { // yield every 3 chars for smoother UI
                        try? await Task.sleep(nanoseconds: delay)
                    }
                }
                streamingMessageId = nil
            } catch {
                isThinking = false
                let errorMsg = ChatMessage(
                    itemURL: item.url,
                    role: "assistant",
                    content: "Sorry, I couldn't get a response: \(error.localizedDescription)"
                )
                modelContext.insert(errorMsg)
                messages.append(errorMsg)
            }
        }
    }
}

// MARK: - Chat Bubble (Markdown + Typewriter)

struct ChatBubble: View {
    let message: ChatMessage
    var streamingText: String? = nil  // non-nil if currently streaming

    /// The text to display — either streaming partial or full content
    private var displayContent: String {
        streamingText ?? message.content
    }

    /// Parse Markdown into AttributedString
    private var renderedMarkdown: AttributedString {
        (try? AttributedString(
            markdown: displayContent,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(displayContent)
    }

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            Text(renderedMarkdown)
                .font(.system(.body, design: .default))
                .foregroundStyle(message.isUser ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if message.isUser {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient.gemini)
                    } else {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(LinearGradient.glassEdge, lineWidth: 0.5)
                            )
                    }
                }
                .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                .textSelection(.enabled)

            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Thinking Indicator (Breathing + Revolving)

struct ThinkingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 2) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(LinearGradient.gemini)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animate ? 1.0 : 0.4)
                        .opacity(animate ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(LinearGradient.glassEdge, lineWidth: 0.5)
                    )
            )
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)

            Spacer(minLength: 60)
        }
        .onAppear { animate = true }
    }
}
