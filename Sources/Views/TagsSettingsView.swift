import SwiftUI
import SwiftData
import LocalAuthentication

/// Settings panel for managing tags/interests and Gemini API key.
struct TagsSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.createdAt, order: .reverse) private var allTags: [Tag]

    @State private var newTagName = ""
    @State private var apiKey = SettingsManager.shared.geminiAPIKey
    @State private var youtubeKey = SettingsManager.shared.youtubeAPIKey
    @State private var syncInterval = SettingsManager.shared.syncIntervalHours
    @State private var showSavedConfirmation = false
    @State private var showYTSavedConfirmation = false
    @State private var apiUnlocked = false
    @State private var ytUnlocked = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text("Manage Interests & Topics")
                    .font(.system(.title3, weight: .bold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Active Tags List
                    tagsSection

                    Divider()

                    // MARK: - Add New Tag
                    addTagSection

                    Divider()

                    // MARK: - Gemini Settings
                    geminiSettingsSection

                    Divider()

                    // MARK: - YouTube API Key
                    youtubeSettingsSection

                    Divider()

                    // MARK: - Sync Settings
                    syncSettingsSection
                }
                .padding(20)
            }
        }
        .frame(minWidth: 400, minHeight: 440)
        .background(.ultraThinMaterial)
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Active Topics", systemImage: "tag")
                .font(.headline)
                .foregroundStyle(.primary)

            if allTags.isEmpty {
                Text("No topics added yet. Add one below to start gathering research.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 4) {
                    ForEach(allTags) { tag in
                        HStack {
                            Circle()
                                .fill(tag.isActive ? LinearGradient.gemini : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing))
                                .frame(width: 8, height: 8)

                            Text(tag.name)
                                .font(.body)

                            Spacer()

                            // Toggle active/inactive
                            Toggle("", isOn: Binding(
                                get: { tag.isActive },
                                set: { tag.isActive = $0 }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.small)

                            // Delete
                            Button {
                                withAnimation {
                                    modelContext.delete(tag)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                            .help("Remove tag")
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(.quaternary.opacity(0.5))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Add Tag Section

    private var addTagSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Add New Topic", systemImage: "plus.circle")
                .font(.headline)

            HStack {
                TextField(
                    "Enter a research topic (e.g., 'Natural Language Processing')",
                    text: $newTagName
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit { addTag() }

                Button("Add Tag") {
                    addTag()
                }
                .buttonStyle(.borderedProminent)
                .tint(.geminiBlue)
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Gemini Settings

    private var hasExistingKey: Bool {
        !SettingsManager.shared.geminiAPIKey.isEmpty
    }

    private var geminiSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("AI API Key", systemImage: "key")
                .font(.headline)

            if hasExistingKey && !apiUnlocked {
                // Locked state — key already saved
                HStack(spacing: 8) {
                    Label("API key configured", systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Spacer()

                    Button {
                        authenticateToUnlock()
                    } label: {
                        Label("API", systemImage: "lock")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .transition(.opacity)
            } else {
                // Unlocked / first-time state
                Text("Get your key from [Google AI Studio](https://aistudio.google.com/apikey)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    SecureField("Enter your API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        SettingsManager.shared.geminiAPIKey = apiKey
                        GeminiService.shared.configure(apiKey: apiKey)
                        showSavedConfirmation = true
                        apiUnlocked = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showSavedConfirmation = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.geminiBlue)
                }

                if showSavedConfirmation {
                    Label("API key saved!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: apiUnlocked)
        .animation(.easeInOut(duration: 0.25), value: hasExistingKey)
    }

    private func authenticateToUnlock() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Fallback: just unlock if biometrics unavailable
            apiKey = SettingsManager.shared.geminiAPIKey
            apiUnlocked = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock to view or change your API key"
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    apiKey = SettingsManager.shared.geminiAPIKey
                    apiUnlocked = true
                }
            }
        }
    }

    // MARK: - Sync Settings

    private var hasExistingYTKey: Bool {
        !SettingsManager.shared.youtubeAPIKey.isEmpty
    }

    private var youtubeSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("YouTube API Key (optional)", systemImage: "play.rectangle")
                .font(.headline)

            if hasExistingYTKey && !ytUnlocked {
                HStack(spacing: 8) {
                    Label("YouTube key configured", systemImage: "checkmark.shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)

                    Spacer()

                    Button {
                        authenticateToUnlockYT()
                    } label: {
                        Label("API", systemImage: "lock")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .transition(.opacity)
            } else {
                Text("Enables YouTube lecture/talk search. Get a key from [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → enable YouTube Data API v3.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    SecureField("YouTube Data API v3 key", text: $youtubeKey)
                        .textFieldStyle(.roundedBorder)

                    Button("Save") {
                        SettingsManager.shared.youtubeAPIKey = youtubeKey
                        showYTSavedConfirmation = true
                        ytUnlocked = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showYTSavedConfirmation = false
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.geminiBlue)
                }

                if showYTSavedConfirmation {
                    Label("YouTube key saved!", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: ytUnlocked)
        .animation(.easeInOut(duration: 0.25), value: showYTSavedConfirmation)
    }

    private func authenticateToUnlockYT() {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            youtubeKey = SettingsManager.shared.youtubeAPIKey
            ytUnlocked = true
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: "Unlock to view or change your YouTube API key"
        ) { success, _ in
            DispatchQueue.main.async {
                if success {
                    youtubeKey = SettingsManager.shared.youtubeAPIKey
                    ytUnlocked = true
                }
            }
        }
    }

    private var syncSettingsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Sync Interval", systemImage: "clock")
                .font(.headline)

            HStack {
                Slider(value: $syncInterval, in: 1...6, step: 0.5) {
                    Text("Interval")
                }
                .frame(maxWidth: 200)

                Text("\(syncInterval, specifier: "%.1f") hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .trailing)
            }
            .onChange(of: syncInterval) { _, newValue in
                SettingsManager.shared.syncIntervalHours = newValue
            }
        }
    }

    // MARK: - Actions

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        // Check duplicates
        if allTags.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            newTagName = ""
            return
        }

        let tag = Tag(name: name)
        modelContext.insert(tag)
        newTagName = ""
    }
}
