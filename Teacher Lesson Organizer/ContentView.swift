import SwiftUI

enum Screen: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", classes = "Classes", students = "Students", lessons = "Lessons", templates = "Lesson Templates", subjects = "Subjects", schedule = "Schedule", attendance = "Attendance", attendanceHistory = "Attendance History", homework = "Homework", notes = "Student Notes", behavior = "Behavior Notes", grades = "Grades", categories = "Grade Categories", tests = "Tests & Quizzes", results = "Test Results", materials = "Teaching Materials", attachments = "Attachments", todo = "To-Do", reminders = "Reminders", upcoming = "Upcoming Lessons", deadlines = "Upcoming Deadlines", calendar = "Calendar", search = "Search", statistics = "Statistics", classProgress = "Class Progress", studentProgress = "Student Progress", archive = "Archive", settings = "Settings", profile = "Teacher Profile", backup = "Backup & Restore", privacy = "Privacy & Storage", workspace = "Workspace"
    var id: String { rawValue }
    var kind: EntryKind? {
        switch self {
        case .classes: .classroom; case .students: .student; case .lessons, .upcoming: .lesson; case .templates: .template; case .subjects: .subject
        case .homework: .homework; case .notes: .note; case .behavior: .behavior; case .grades: .grade; case .categories: .category
        case .tests: .assessment; case .materials, .attachments: .material; case .todo: .task; case .reminders: .reminder; default: nil
        }
    }
    var icon: String {
        if let kind { return kind.icon }
        return switch self {
        case .dashboard: "square.grid.2x2"; case .schedule, .calendar: "calendar"; case .attendance, .attendanceHistory: "person.badge.clock"
        case .deadlines: "clock"; case .results: "checkmark.seal"; case .search: "magnifyingglass"; case .statistics, .classProgress, .studentProgress: "chart.xyaxis.line"
        case .archive: "archivebox"; case .settings: "gearshape"; case .profile: "person.crop.circle"; case .backup: "externaldrive"; case .privacy: "lock.shield"; default: "square.grid.2x2"
        }
    }
}
struct ContentView: View {
    @ObservedObject var store: OrganizerStore
    @AppStorage("onboardingComplete") private var onboarded = false
    @State private var incomingBackupPrompt = false
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ZStack {
            if !store.ready { LaunchScreen(title: "Loading workspace…") }
            else if store.loadFailed { StorageRecoveryView() }
            else if !onboarded { OnboardingView { withAnimation(.easeInOut(duration: 0.45)) { onboarded = true } } }
            else { MainShell().id(store.sessionID) }
        }
        .environmentObject(store).environment(\.locale, Locale(identifier: "en_US")).tint(.gold).preferredColorScheme(.light)
        .task {
            if !store.ready { store.load() }
        }
        .onChange(of: store.incomingBackupURL, initial: true) { _, url in incomingBackupPrompt = url != nil }
        .confirmationDialog("Restore this backup? This replaces the current workspace.", isPresented: $incomingBackupPrompt, titleVisibility: .visible) {
            Button("Restore backup", role: .destructive) {
                guard let url = store.incomingBackupURL else { return }
                do { try store.restore(url); onboarded = true } catch { store.error = error.localizedDescription }
                store.dismissIncomingBackup()
            }
            Button("Cancel", role: .cancel) { store.dismissIncomingBackup() }
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active && store.ready { store.synchronizeReminders() } }
        .alert("Workspace", isPresented: Binding(get: { store.error != nil || store.notice != nil }, set: { if !$0 { store.error = nil; store.notice = nil } })) {
            if store.notice?.contains("Enable notifications") == true { Button("Open Settings") { if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }; store.notice = nil } }
            Button("OK") { store.error = nil; store.notice = nil }
        } message: { Text(store.error ?? store.notice ?? "") }
    }
}
struct LaunchScreen: View {
    var title = "Connecting…"

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.97, blue: 0.965).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color(red: 0.26, green: 0.29, blue: 0.32))
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color(red: 0.12, green: 0.15, blue: 0.18))
                Text("Please wait a moment.")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.31, green: 0.34, blue: 0.37))
            }
            .multilineTextAlignment(.center)
            .padding(24)
            .accessibilityElement(children: .combine)
        }
    }
}
struct OnboardingView: View {
    @EnvironmentObject var store: OrganizerStore
    var finish: () -> Void
    @State private var step = 0
    @State private var name = ""
    @State private var sample = false
    let titles = ["Space to teach.\nRoom to think.", "Every learner,\nseen clearly.", "Your day.\nBeautifully arranged."]
    let subtitles = ["Your classes, lessons and ideas, thoughtfully gathered in one personal workspace.", "Keep meaningful notes, track progress and celebrate the small steps that matter.", "A calm place to plan ahead. Everything stays on your device, ready whenever you are."]
    var body: some View {
        GeometryReader { geometry in
        ScrollView {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Emblem(size: 40); Spacer(); Text("TEACHER'S WORKSPACE").font(.system(size: 9, weight: .semibold)).tracking(2).foregroundStyle(Color.gold) }.padding(.top, 22)
            Spacer(minLength: 18)
            WelcomeArtwork(step: step).frame(maxWidth: .infinity).frame(height: 310).accessibilityHidden(true)
            Spacer(minLength: 18)
            Text(titles[step]).font(.system(size: 42, design: .serif)).tracking(-1.4).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true).id(step).transition(.opacity)
            Text(subtitles[step]).font(.subheadline).foregroundStyle(Color.secondaryInk).lineSpacing(5).padding(.top, 14).fixedSize(horizontal: false, vertical: true)
            if step == 2 {
                TextField("Your name (optional)", text: $name).textContentType(.name).padding(14).background(.white, in: RoundedRectangle(cornerRadius: 12)).padding(.top, 18)
                if store.workspace.entries.isEmpty { Toggle("Explore with sample data", isOn: $sample).font(.subheadline).tint(.sage).padding(.vertical, 12) }
            }
            Spacer(minLength: 22)
            HStack(spacing: 7) { ForEach(0..<3) { i in Capsule().fill(i == step ? Color.gold : Color.ink.opacity(0.12)).frame(width: i == step ? 24 : 6, height: 6) }; Spacer(); Text("0\(step + 1) / 03").font(.caption.monospaced()).foregroundStyle(Color.secondaryInk) }.padding(.bottom, 23)
            Button {
                if step < 2 { withAnimation(.easeInOut(duration: 0.3)) { step += 1 } }
                else { if store.setTeacher(name) { if sample && store.workspace.entries.isEmpty { guard store.loadSample() else { return } }; finish() } }
            } label: { HStack { Text(step == 2 ? "Open my workspace" : "Continue"); Spacer(); Image(systemName: "arrow.right") }.padding(.horizontal, 20) }.buttonStyle(GoldButton())
            if step > 0 { Button("Back") { withAnimation { step -= 1 } }.font(.caption).frame(maxWidth: .infinity).padding(.top, 12) }
        }.padding(.horizontal, 30).frame(maxWidth: 540).frame(minHeight: max(0, geometry.size.height - 22)).padding(.bottom, 22).frame(maxWidth: .infinity)
        }.scrollDismissesKeyboard(.interactively).background(Color.paper.ignoresSafeArea()).onAppear { name = store.workspace.teacher }
        }
    }
}
enum ContextRoute: Hashable {
    case attendance(UUID?, Date)
    case progress(Screen, UUID?)
}
struct OrganizerNavigation<Root: View>: View {
    @State private var localPath = NavigationPath()
    var root: Root
    var suppliedPath: Binding<NavigationPath>?
    init(path: Binding<NavigationPath>? = nil, @ViewBuilder root: () -> Root) { self.suppliedPath = path; self.root = root() }
    var body: some View {
        NavigationStack(path: suppliedPath ?? $localPath) {
            root.toolbar(.hidden, for: .tabBar).toolbarBackground(Color.paper, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar)
                .navigationDestination(for: Screen.self) { ScreenView(screen: $0) }
                .navigationDestination(for: Entry.self) { EntryDetailView(id: $0.id) }
                .navigationDestination(for: UUID.self) { EntryDetailView(id: $0) }
                .navigationDestination(for: ContextRoute.self) { route in
                    switch route {
                    case .attendance(let classID, let date): AttendancePage(initialClassID: classID, initialDate: date)
                    case .progress(let mode, let id): ProgressPage(mode: mode, initialSelection: id)
                    }
                }
        }
    }
}
struct MainShell: View {
    @EnvironmentObject private var store: OrganizerStore
    @State private var tab = 0
    @State private var studioPath = NavigationPath()
    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $tab) {
                OrganizerNavigation { DashboardView() }.tabItem { Label("Today", systemImage: "square.grid.2x2") }.tag(0)
                OrganizerNavigation { ScreenView(screen: .classes) }.tabItem { Label("Classes", systemImage: "person.2") }.tag(1)
                OrganizerNavigation { CalendarPage() }.tabItem { Label("Planner", systemImage: "calendar") }.tag(2)
                OrganizerNavigation { ScreenView(screen: .homework) }.tabItem { Label("Homework", systemImage: "tray.full") }.tag(3)
                OrganizerNavigation(path: $studioPath) { WorkspaceView() }.tabItem { Label("Workspace", systemImage: "square.stack.3d.up") }.tag(4)
            }
            .toolbar(.hidden, for: .tabBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            PremiumTabBar(selection: $tab)
                .padding(.horizontal, 20).padding(.top, 9).padding(.bottom, 6)
        }
        .background(Color.paper.ignoresSafeArea(edges: .bottom))
        .tint(.gold).sensoryFeedback(.selection, trigger: tab)
        .onChange(of: store.reminderRoute) { _, _ in openReminder() }
        .onAppear { openReminder() }
    }
    private func openReminder() {
        guard let id = store.reminderRoute else { return }
        store.reminderRoute = nil
        guard store.entry(id)?.kind == .reminder else { store.notice = "This reminder is no longer available."; return }
        tab = 4; studioPath = NavigationPath(); studioPath.append(id)
    }
}
struct PremiumTabBar: View {
    @Binding var selection: Int
    @Namespace private var tabAnimation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let items = [("Today", "square.grid.2x2"), ("Classes", "person.2"), ("Planner", "calendar"), ("Homework", "tray.full"), ("Studio", "square.stack.3d.up")]
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<items.count, id: \.self) { index in
                Button { withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.78)) { selection = index } } label: {
                    VStack(spacing: 6) {
                        Image(systemName: items[index].1).font(.system(size: 18, weight: .light)).symbolVariant(selection == index ? .fill : .none)
                        Text(items[index].0).font(.system(size: 8, weight: selection == index ? .semibold : .regular)).tracking(0.25)
                    }.foregroundStyle(selection == index ? Color.champagne : Color.paper.opacity(0.45))
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background { if selection == index { RoundedRectangle(cornerRadius: 17).fill(.white.opacity(0.08)).matchedGeometryEffect(id: "activeTab", in: tabAnimation) } }
                }.buttonStyle(.plain).accessibilityLabel(items[index].0).accessibilityAddTraits(selection == index ? .isSelected : [])
            }
        }.padding(7).background(Color.ink, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.champagne.opacity(0.15), lineWidth: 0.7))
            .shadow(color: .ink.opacity(0.15), radius: 15, x: 0, y: 7)
    }
}
struct ScreenView: View {
    var screen: Screen
    var body: some View {
        Group {
            if let kind = screen.kind { CollectionPage(screen: screen, kind: kind) }
            else {
                switch screen {
                case .dashboard: DashboardView()
                case .schedule, .calendar: CalendarPage(scheduleOnly: screen == .schedule)
                case .attendance: AttendancePage()
                case .attendanceHistory: AttendanceHistoryPage()
                case .statistics, .classProgress, .studentProgress: ProgressPage(mode: screen)
                case .settings, .profile, .backup, .privacy: SettingsPage(screen: screen)
                case .search: SearchPage()
                case .results: ResultsPage()
                case .deadlines: DeadlinesPage()
                case .archive: ArchivePage()
                default: WorkspaceView()
                }
            }
        }.navigationBarTitleDisplayMode(.inline)
    }
}
