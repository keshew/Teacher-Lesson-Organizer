import SwiftUI
import UniformTypeIdentifiers

struct SearchPage: View {
    @EnvironmentObject var store: OrganizerStore
    @State private var query = ""
    @State private var kind: EntryKind?
    var results: [Entry] { store.workspace.entries.filter { !$0.archived && (kind == nil || $0.kind == kind) && !query.isEmpty && ($0.title + " " + $0.detail + " " + $0.objectives + " " + $0.activities).localizedCaseInsensitiveContains(query) }.sorted { $0.title < $1.title } }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "Find a little clarity", title: "Search your workspace.")
            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.gold)
                TextField("Search everything", text: $query).font(.subheadline).submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.secondaryInk) }.accessibilityLabel("Clear search")
                }
            }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.fineLine, lineWidth: 0.7))
            Picker("Look in", selection: $kind) { Text("All collections").tag(nil as EntryKind?); ForEach(EntryKind.allCases) { Text($0.singular).tag(Optional($0)) } }.tint(.ink)
            if results.isEmpty { EmptyCard(icon: "magnifyingglass", title: query.isEmpty ? "A thought, a name, an idea." : "No matches yet.", message: query.isEmpty ? "Search classes, people, plans, notes and resources." : "Try another phrase or choose a different collection.") }
            else { SectionLabel(title: "Found in your workspace", caption: "\(results.count) results") }
            ForEach(results) { result in NavigationLink(value: result) { PaperCard { VStack(alignment: .leading, spacing: 8) { Text(result.kind.singular.uppercased()).font(.system(size: 8, weight: .semibold)).tracking(2).foregroundStyle(Color.gold); EntryRow(entry: result) } } }.buttonStyle(.plain) }
        }.navigationTitle("Search")
    }
}
struct ArchivePage: View {
    @EnvironmentObject var store: OrganizerStore
    var entries: [Entry] { store.workspace.entries.filter(\.archived).sorted { $0.createdAt > $1.createdAt } }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "Kept, with care", title: "The archive.", subtitle: "Make room for today without losing yesterday.")
            if entries.isEmpty { EmptyCard(icon: "archivebox", title: "Nothing tucked away.", message: "Archive a record from its detail page. You can restore it whenever you need it.") }
            ForEach(entries) { entry in NavigationLink(value: entry) { PaperCard { EntryRow(entry: entry) } }.buttonStyle(.plain) }
        }.navigationTitle("Archive")
    }
}
struct SettingsPage: View {
    @EnvironmentObject var store: OrganizerStore
    var screen: Screen = .settings
    @State private var name = ""
    @State private var backupURL: URL?
    @State private var importing = false
    @State private var restoring = false
    @State private var resetting = false
    @State private var importURL: URL?
    @State private var showOnboarding = false
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "Make yourself at home", title: screen == .settings ? "A personal workspace." : screen.rawValue + ".")
            if screen == .settings {
                PaperCard { HStack(spacing: 15) { Emblem(size: 50); VStack(alignment: .leading, spacing: 5) { Text(store.workspace.teacher.isEmpty ? "Your teaching space" : store.workspace.teacher).font(.system(size: 22, design: .serif)); Text("Teacher Lesson Organizer · \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2"))").font(.caption).foregroundStyle(Color.secondaryInk) } } }
                VStack(spacing: 12) { ForEach([Screen.profile, .backup, .privacy]) { item in NavigationLink(value: item) { PaperCard { HStack { Label(item.rawValue, systemImage: item.icon).font(.subheadline); Spacer(); Image(systemName: "chevron.right").font(.caption) }.foregroundStyle(Color.ink) } } } }
                Button { showOnboarding = true } label: { PaperCard { Label("Revisit the welcome tour", systemImage: "book.pages").font(.subheadline).foregroundStyle(Color.ink) } }
                PaperCard { VStack(alignment: .leading, spacing: 14) { Label("On-device reminders", systemImage: "bell").font(.system(size: 21, design: .serif)); Text("Notifications are scheduled for the next 64 future reminders. Opening the app refreshes the schedule.").font(.caption).foregroundStyle(Color.secondaryInk); Button("Open notification settings", systemImage: "arrow.up.right") { if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) } }.font(.subheadline) } }
                SectionLabel(title: "Room for a fresh start")
                PaperCard { VStack(alignment: .leading, spacing: 14) { Text("Start over with an empty workspace. Export a backup first if you want to keep your records.").font(.subheadline).foregroundStyle(Color.secondaryInk); Button("Erase workspace…", role: .destructive) { resetting = true }.font(.subheadline) } }
            }
            if screen == .profile {
                PaperCard { VStack(alignment: .leading, spacing: 16) { Text("How should we greet you?").font(.system(size: 22, design: .serif)); TextField("Your name", text: $name).textContentType(.name).padding(14).background(Color.paper, in: RoundedRectangle(cornerRadius: 12)); Button("Save profile") { if store.setTeacher(name) { store.notice = "Profile saved." } }.buttonStyle(GoldButton()) } }
            }
            if screen == .backup {
                PaperCard { VStack(alignment: .leading, spacing: 15) { Image(systemName: "externaldrive").font(.largeTitle).foregroundStyle(Color.gold); Text("Keep a copy, your way.").font(.system(size: 24, design: .serif)); Text("Export a file containing your records and attachments. Store it somewhere safe, or move it to another device yourself.").font(.subheadline).foregroundStyle(Color.secondaryInk).lineSpacing(4); Button("Prepare backup", systemImage: "square.and.arrow.up") { do { backupURL = try store.exportBackup() } catch { store.error = error.localizedDescription } }.buttonStyle(GoldButton()); if let backupURL { ShareLink(item: backupURL) { Label("Save or share backup file", systemImage: "square.and.arrow.up").font(.subheadline) } } } }
                PaperCard { VStack(alignment: .leading, spacing: 15) { Text("Restore your workspace").font(.system(size: 24, design: .serif)); Text("Restoring replaces the current workspace with the contents of your backup. Future reminders are synchronized with this device.").font(.subheadline).foregroundStyle(Color.secondaryInk); Button("Choose a backup file", systemImage: "folder") { importing = true }.font(.subheadline) } }
            }
            if screen == .privacy {
                PaperCard { VStack(alignment: .leading, spacing: 17) {
                    Label("Stored on this device", systemImage: "lock.shield").font(.system(size: 23, design: .serif))
                    Text("Your classes, students, notes and attachments live in the app's private storage. The app uses Firebase for remote notifications and Adjust to measure installs and advertising.").font(.subheadline).foregroundStyle(Color.secondaryInk).lineSpacing(5)
                    Text("Local reminders use iOS notifications. Workspace backups can be exported or shared from the app. Your device's own backup settings are managed by iOS.").font(.subheadline).foregroundStyle(Color.secondaryInk).lineSpacing(5)
                    Divider()
                    LabeledContent("Records", value: "\(store.workspace.entries.count)")
                    LabeledContent("Attendance marks", value: "\(store.workspace.attendance.count)")
                    LabeledContent("Attachments", value: "\(store.workspace.entries.filter { $0.fileName != nil }.count)")
                }.foregroundStyle(Color.ink) }
                PaperCard { Text("Deleting the app can remove its local data. Export a backup regularly to keep a separate copy.").font(.subheadline).foregroundStyle(Color.secondaryInk) }
            }
        }.navigationTitle(screen.rawValue).navigationBarTitleDisplayMode(.inline)
            .onAppear { name = store.workspace.teacher }
            .onDisappear { store.discardBackupImport(importURL) }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.teacherWorkspace, .json]) { result in switch result { case .success(let url): do { store.discardBackupImport(importURL); importURL = try store.stageBackup(url); restoring = true } catch { store.error = error.localizedDescription }; case .failure(let error): store.error = error.localizedDescription } }
            .confirmationDialog("Replace this workspace with your backup?", isPresented: $restoring, titleVisibility: .visible) { Button("Restore backup", role: .destructive) { restoreSelectedBackup() }; Button("Cancel", role: .cancel) { store.discardBackupImport(importURL); importURL = nil } }
            .confirmationDialog("Erase all classes, students, lessons, notes and attachments? This cannot be undone without a backup.", isPresented: $resetting, titleVisibility: .visible) { Button("Erase all data", role: .destructive) { if store.reset() { backupURL = nil; store.notice = "Your workspace is now empty." } }; Button("Cancel", role: .cancel) { } }
            .fullScreenCover(isPresented: $showOnboarding) { OnboardingView { showOnboarding = false } }
    }
    private func restoreSelectedBackup() {
        guard let url = importURL else { return }
        defer { store.discardBackupImport(url); importURL = nil }
        do { try store.restore(url); backupURL = nil } catch { store.error = "The backup could not be restored. \(error.localizedDescription)" }
    }
}

struct StorageRecoveryView: View {
    @EnvironmentObject var store: OrganizerStore
    @State private var importing = false
    @State private var restoreURL: URL?
    @State private var confirm = false
    var body: some View {
        Page {
            Emblem(size: 65).padding(.top, 35)
            EditorialTitle(eyebrow: "Your records deserve care", title: "Let's reopen your workspace.", subtitle: "The saved file could not be read. Your existing data has been left in place.")
            PaperCard { Text("Try opening it again, or restore a backup you exported earlier. You can also save a copy of the current file before restoring.").font(.subheadline).foregroundStyle(Color.secondaryInk).lineSpacing(5) }
            Button("Try again", systemImage: "arrow.clockwise") { store.load() }.buttonStyle(GoldButton())
            Button("Choose a backup", systemImage: "folder") { importing = true }.font(.subheadline)
            if FileManager.default.fileExists(atPath: store.dataURL.path) { ShareLink(item: store.dataURL) { Label("Save a copy of the current file", systemImage: "square.and.arrow.up").font(.subheadline) } }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.teacherWorkspace, .json]) { result in switch result { case .success(let url): do { store.discardBackupImport(restoreURL); restoreURL = try store.stageBackup(url); confirm = true } catch { store.error = error.localizedDescription }; case .failure(let error): store.error = error.localizedDescription } }
        .confirmationDialog("Replace the unreadable workspace with this backup?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Restore backup", role: .destructive) { guard let url = restoreURL else { return }; defer { store.discardBackupImport(url); restoreURL = nil }; do { try store.restore(url) } catch { store.error = error.localizedDescription } }
            Button("Cancel", role: .cancel) { store.discardBackupImport(restoreURL); restoreURL = nil }
        }
    }
}
