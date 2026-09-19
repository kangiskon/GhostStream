import SwiftUI

/// First-run / add-source form. Starts completely empty — the user provides
/// either a playlist (URL or pasted text) or provider credentials.
/// No content, playlists, or credentials are pre-filled or bundled.
struct AddSourceView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService
    @Environment(\.dismiss) private var dismiss

    enum Mode: String, CaseIterable, Identifiable {
        case m3uURL = "Playlist URL"
        case m3uText = "Paste Playlist"
        case xtream = "Provider"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .m3uURL
    @State private var name = ""

    // M3U
    @State private var m3uURL = ""
    @State private var m3uText = ""

    // Xtream
    @State private var serverURL = ""
    @State private var username = ""
    @State private var password = ""

    // Optional EPG
    @State private var epgURL = ""

    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var confirmsContentRights = false

    /// Allows the launcher to open a specific sub-form directly (e.g. Xtream).
    /// `onSaved` lets the first-run launcher close itself after a source is
    /// successfully validated and activated.
    private let onSaved: (() -> Void)?

    init(initialMode: Mode = .m3uURL, onSaved: (() -> Void)? = nil) {
        _mode = State(initialValue: initialMode)
        self.onSaved = onSaved
    }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Theme.card)

            Section("Name") {
                TextField("My Source", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .listRowBackground(Theme.card)

            switch mode {
            case .m3uURL:
                Section("Playlist URL") {
                    TextField("https://example.com/playlist.m3u", text: $m3uURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Theme.card)
            case .m3uText:
                Section("Paste M3U") {
                    TextEditor(text: $m3uText)
                        .frame(minHeight: 160)
                        .autocorrectionDisabled()
                }
                .listRowBackground(Theme.card)
            case .xtream:
                Section("Provider Login") {
                    TextField("Server URL (https://host:port)", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                }
                .listRowBackground(Theme.card)
            }

            Section("Guide Data (optional)") {
                TextField("XMLTV URL (optional)", text: $epgURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .listRowBackground(Theme.card)

            Section("Content & Rights") {
                Toggle(isOn: $confirmsContentRights) {
                    Text("I confirm that I have permission to access and play the content I add to GhostStream.")
                        .font(.footnote)
                }
                Text("GhostStream is a media player and does not provide channels, subscriptions, playlists, or media content.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Theme.card)

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.footnote)
                }
                .listRowBackground(Theme.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Add Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                if isValidating {
                    ProgressView()
                } else {
                    Button("Save") { Task { await save() } }
                        .disabled(!isFormValid)
                }
            }
        }
    }

    private var isFormValid: Bool {
        guard confirmsContentRights else { return false }
        switch mode {
        case .m3uURL:
            return !m3uURL.trimmingCharacters(in: .whitespaces).isEmpty
        case .m3uText:
            return !m3uText.trimmingCharacters(in: .whitespaces).isEmpty
        case .xtream:
            return !serverURL.trimmingCharacters(in: .whitespaces).isEmpty
                && !username.trimmingCharacters(in: .whitespaces).isEmpty
                && !password.isEmpty
        }
    }

    private func save() async {
        errorMessage = nil
        isValidating = true
        defer { isValidating = false }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let epg = epgURL.trimmingCharacters(in: .whitespaces)
        let epgOptional = epg.isEmpty ? nil : epg

        let source: Source
        switch mode {
        case .m3uURL:
            source = Source(name: trimmedName.isEmpty ? "Playlist" : trimmedName,
                            kind: .m3uURL,
                            m3uURL: m3uURL.trimmingCharacters(in: .whitespaces),
                            epgURL: epgOptional)
        case .m3uText:
            source = Source(name: trimmedName.isEmpty ? "Saved Playlist" : trimmedName,
                            kind: .m3uText,
                            m3uText: m3uText,
                            epgURL: epgOptional)
        case .xtream:
            source = Source(name: trimmedName.isEmpty ? "Provider Account" : trimmedName,
                            kind: .xtream,
                            serverURL: serverURL.trimmingCharacters(in: .whitespaces),
                            username: username.trimmingCharacters(in: .whitespaces),
                            password: password,
                            epgURL: epgOptional)
        }

        // Fetch the source now, while the Connect/Save screen is still visible.
        // This removes the old race where the form closed after authentication
        // but the parent view never actually fetched the source library.
        await library.load(source: source)
        guard library.loadedSourceID == source.id else {
            errorMessage = library.errorMessage ?? "The source connected, but no media data could be fetched."
            return
        }

        store.add(source)
        store.setActive(source)
        onSaved?()
        dismiss()
    }
}
