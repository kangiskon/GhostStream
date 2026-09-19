import SwiftUI
import UniformTypeIdentifiers

/// First-run / source switcher rebuilt to match the unified black/purple GhostStream design.
struct LauncherView: View {
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService
    @Environment(\.presentationMode) private var presentationMode

    var onClose: (() -> Void)? = nil

    private enum Route: Identifiable {
        case m3u, xtream, singleStream, savedSources
        var id: Int { hashValue }
    }

    @State private var route: Route?
    @State private var showFileImporter = false
    @State private var importError: String?
    @State private var pendingImportedSource: Source?

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        GeometryReader { proxy in
            let safeWidth = max(proxy.size.width - proxy.safeAreaInsets.leading - proxy.safeAreaInsets.trailing, 1)
            let safeHeight = max(proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom, 1)
            let isPadLike = safeWidth >= 700
            let contentWidth = max(1, min(safeWidth - (isPadLike ? 56 : 28), isPadLike ? 980 : 560))
            let tileHeight = min(max(safeHeight * (isPadLike ? 0.16 : 0.135), 108), isPadLike ? 170 : 132)
            let logoSize = min(max(contentWidth * (isPadLike ? 0.15 : 0.28), 104), isPadLike ? 156 : 132)
            let titleSize = min(max(contentWidth * 0.075, 27), isPadLike ? 48 : 36)

            ZStack(alignment: .topLeading) {
                Theme.background.ignoresSafeArea()
                Image("GhostHomeHero")
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.32)
                    .overlay(
                        LinearGradient(
                            colors: [.black.opacity(0.12), Theme.background.opacity(0.62), Theme.background.opacity(0.98)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(Theme.heroGlow)
                    .allowsHitTesting(false)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: isPadLike ? 22 : 16) {
                        Spacer().frame(height: isPadLike ? 18 : 8)

                        Image("GhostBrandExact")
                            .resizable()
                            .scaledToFit()
                            .frame(width: logoSize, height: logoSize)
                            .clipShape(RoundedRectangle(cornerRadius: isPadLike ? 30 : 24))
                            .overlay(RoundedRectangle(cornerRadius: isPadLike ? 30 : 24).stroke(Theme.accent.opacity(0.65), lineWidth: 1))

                        HStack(spacing: 0) {
                            Text("GHOST").foregroundStyle(.white)
                            Text("STREAM").foregroundStyle(Theme.accentBright)
                        }
                        .font(.system(size: titleSize, weight: .black, design: .rounded))
                        .tracking(isPadLike ? 3 : 2)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)

                        Text("YOUR STREAMS • YOUR RULES")
                            .font(.system(size: isPadLike ? 13 : 9, weight: .bold))
                            .tracking(isPadLike ? 4 : 3)
                            .foregroundStyle(Theme.accentBright.opacity(0.86))
                            .minimumScaleFactor(0.8)
                            .lineLimit(1)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: isPadLike ? 16 : 10), GridItem(.flexible(), spacing: isPadLike ? 16 : 10)], spacing: isPadLike ? 16 : 10) {
                            launcherTile("PLAYLIST URL", icon: "list.and.film", minHeight: tileHeight, isLarge: isPadLike) { route = .m3u }
                            launcherTile("M3U FILE", icon: "doc.badge.plus", minHeight: tileHeight, isLarge: isPadLike) { showFileImporter = true }
                            launcherTile("PROVIDER LOGIN", icon: "key.fill", minHeight: tileHeight, isLarge: isPadLike) { route = .xtream }
                            launcherTile("SINGLE STREAM", icon: "play.rectangle.fill", minHeight: tileHeight, isLarge: isPadLike) { route = .singleStream }
                        }
                        .padding(.top, isPadLike ? 14 : 8)

                        Button { route = .savedSources } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "externaldrive.fill")
                                    .font(.system(size: isPadLike ? 25 : 18))
                                    .foregroundStyle(Theme.accentBright)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("SAVED SOURCES")
                                        .font(.system(size: isPadLike ? 17 : 13, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(.white)
                                    Text("Switch without re-entering your details")
                                        .font(isPadLike ? .subheadline : .caption)
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(Theme.accentBright)
                            }
                            .padding(isPadLike ? 20 : 14)
                            .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: isPadLike ? 14 : 10))
                            .overlay(RoundedRectangle(cornerRadius: isPadLike ? 14 : 10).stroke(Theme.accent.opacity(0.40), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Text("GhostStream plays only sources you add. Use content you are authorized to access.")
                            .font(isPadLike ? .footnote : .caption2)
                            .foregroundStyle(.white.opacity(0.48))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.top, 6)
                    }
                    .frame(width: contentWidth)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, max(24, proxy.safeAreaInsets.bottom + 16))
                }

                if onClose != nil {
                    Button(action: closeLauncher) {
                        HStack(spacing: 7) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                                .font(.caption.bold())
                                .tracking(1.0)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 42)
                        .background(Color.black.opacity(0.72), in: Capsule())
                        .overlay(Capsule().stroke(Theme.accent.opacity(0.65), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, max(14, proxy.safeAreaInsets.leading + 10))
                    .padding(.top, max(10, proxy.safeAreaInsets.top + 6))
                    .accessibilityLabel("Back from Change Source")
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $route) { r in NavigationStack { destination(for: r) } }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [UTType.plainText, UTType.item], allowsMultipleSelection: false) { result in handleFileImport(result) }
        .alert("Couldn't import file", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK", role: .cancel) { importError = nil }
        } message: { Text(importError ?? "") }
        .confirmationDialog("Confirm Content Rights", isPresented: Binding(get: { pendingImportedSource != nil }, set: { if !$0 { pendingImportedSource = nil } }), titleVisibility: .visible) {
            Button("I Have Permission — Add Playlist") {
                guard let source = pendingImportedSource else { return }
                Task {
                    await library.load(source: source)
                    guard library.loadedSourceID == source.id else {
                        importError = library.errorMessage ?? "The playlist could not be loaded."
                        pendingImportedSource = nil
                        return
                    }
                    store.add(source)
                    store.setActive(source)
                    pendingImportedSource = nil
                    onClose?()
                    presentationMode.wrappedValue.dismiss()
                }
            }
            Button("Cancel", role: .cancel) { pendingImportedSource = nil }
        } message: {
            Text("Only add and play content you are authorized to access. GhostStream does not provide the media in this playlist.")
        }
    }

    private func launcherTile(_ title: String, icon: String, minHeight: CGFloat, isLarge: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: icon).font(.system(size: isLarge ? 38 : 28, weight: .light)).foregroundStyle(Theme.accentBright)
                Text(title).font(.system(size: isLarge ? 15 : 11, weight: .bold)).tracking(isLarge ? 1.1 : 0.8).foregroundStyle(.white).multilineTextAlignment(.center).minimumScaleFactor(0.75).lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background(Theme.cardGradient, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.accent.opacity(0.55), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .m3u:
            AddSourceView(initialMode: .m3uURL, onSaved: sourceSavedFromLauncher)
        case .xtream:
            AddSourceView(initialMode: .xtream, onSaved: sourceSavedFromLauncher)
        case .singleStream:
            SingleStreamEntryView()
        case .savedSources:
            SavedSourcesView(onSelected: {
                onClose?(); presentationMode.wrappedValue.dismiss()
            })
        }
    }

    // CHANGE SOURCE can always be exited without selecting a service.
    private func closeLauncher() {
        onClose?()
        presentationMode.wrappedValue.dismiss()
    }

    private func sourceSavedFromLauncher() {
        onClose?(); presentationMode.wrappedValue.dismiss()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let accessed = url.startAccessingSecurityScopedResource(); defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            let text = try String(contentsOf: url, encoding: .utf8)
            guard text.localizedCaseInsensitiveContains("#EXTM3U") else { throw ImportFailure.notPlaylist }
            pendingImportedSource = Source(name: url.deletingPathExtension().lastPathComponent, kind: .m3uText, m3uText: text)
        } catch { importError = error.localizedDescription }
    }

    private enum ImportFailure: LocalizedError {
        case notPlaylist
        var errorDescription: String? { "That file doesn't appear to be a valid M3U playlist." }
    }
}

// MARK: - Single stream entry (plays one URL without saving)

private struct SingleStreamEntryView: View {
    @Environment(\.presentationMode) private var presentationMode
    @State private var urlString = ""
    @State private var showPlayer = false
    @State private var confirmsContentRights = false

    private var isValid: Bool {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme != nil else { return false }
        return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && confirmsContentRights
    }

    var body: some View {
        Form {
            Section("Stream URL") {
                TextField("http(s):// stream URL", text: $urlString)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .listRowBackground(Theme.card)

            Section("Content & Rights") {
                Toggle("I have permission to play this content", isOn: $confirmsContentRights)
                Text("Plays a single user-provided stream directly. Nothing is saved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Play Single Stream")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { presentationMode.wrappedValue.dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Play") { showPlayer = true }
                    .disabled(!isValid)
            }
        }
        .navigationDestination(isPresented: $showPlayer) {
            PlayerView(
                title: "Stream",
                urlString: urlString.trimmingCharacters(in: .whitespacesAndNewlines),
                kind: .live
            )
        }
    }
}

// MARK: - Saved sources picker

private struct SavedSourcesView: View {
    var onSelected: (() -> Void)? = nil
    @EnvironmentObject private var store: SourceStore
    @EnvironmentObject private var library: LibraryViewModel
    @EnvironmentObject private var epg: EPGService
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        Group {
            if store.sources.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(Theme.accent)
                    Text("No saved services yet")
                        .font(.headline)
                    Text("Add a playlist or provider login to see it here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(store.sources) { source in
                        Button {
                            Task {
                                // Load and validate the selected source before
                                // publishing it as active. Setting active first
                                // triggers RootTabView's reload task and can race
                                // this picker, leaving the library empty/stale.
                                epg.clear()
                                await library.load(source: source)
                                guard library.loadedSourceID == source.id else { return }
                                if source.kind == .xtream || source.epgURL != nil {
                                    await epg.load(for: source)
                                }
                                store.setActive(source)
                                onSelected?()
                                presentationMode.wrappedValue.dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name).foregroundColor(.primary)
                                    Text(kindLabel(source.kind))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if store.activeSourceID == source.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(Theme.accent)
                                }
                            }
                        }
                        .listRowBackground(Theme.card)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Saved Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { presentationMode.wrappedValue.dismiss() }
            }
        }
    }

    private func kindLabel(_ kind: Source.Kind) -> String {
        switch kind {
        case .m3uURL: return "Playlist URL"
        case .m3uText: return "Saved Playlist"
        case .xtream: return "Provider Login"
        }
    }

    private func delete(at offsets: IndexSet) {
        let toRemove = offsets.map { store.sources[$0] }
        for source in toRemove { store.remove(source) }
        if store.activeSource == nil {
            library.reset()
            epg.clear()
        }
    }
}
