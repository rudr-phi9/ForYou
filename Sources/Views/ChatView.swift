import SwiftUI
import SwiftData

/// Chat window for asking questions about a specific research item.
/// Persists messages via SwiftData keyed on item URL.
struct ChatView: View {
    let item: ResearchItem
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isThinking = false

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
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messages) { msg in
                            ChatBubble(message: msg)
                                .id(msg.id)
                        }

                        if isThinking {
                            ThinkingIndicator()
                                .id("thinking")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .onChange(of: messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: isThinking) { _, _ in
                    scrollToBottom(proxy: proxy)
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
        let itemContent = item.rawTextContent

        Task {
            do {
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
            } catch {
                let errorMsg = ChatMessage(
                    itemURL: item.url,
                    role: "assistant",
                    content: "Sorry, I couldn't get a response: \(error.localizedDescription)"
                )
                modelContext.insert(errorMsg)
                messages.append(errorMsg)
            }
            isThinking = false
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 60) }

            Text(message.content)
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
