import Foundation
import SwiftUI
import Combine
@preconcurrency import UserNotifications
import UniformTypeIdentifiers

enum EntryKind: String, Codable, CaseIterable, Identifiable {
    case classroom, student, lesson, template, subject, homework, note, behavior, grade, category, assessment, material, task, reminder
    var id: String { rawValue }
    var singular: String {
        switch self {
        case .classroom: "Class"; case .student: "Student"; case .lesson: "Lesson"; case .template: "Lesson template"
        case .subject: "Subject"; case .homework: "Homework"; case .note: "Student note"; case .behavior: "Behavior note"
        case .grade: "Grade"; case .category: "Grade category"; case .assessment: "Test or quiz"; case .material: "Teaching material"
        case .task: "Task"; case .reminder: "Reminder"
        }
    }
    var icon: String {
        switch self {
        case .classroom: "rectangle.3.group"; case .student: "person"; case .lesson: "book.closed"; case .template: "doc.on.doc"
        case .subject: "books.vertical"; case .homework: "tray.full"; case .note: "note.text"; case .behavior: "hand.thumbsup"
        case .grade: "chart.bar.xaxis"; case .category: "tag"; case .assessment: "checkmark.seal"; case .material: "folder"
        case .task: "checklist"; case .reminder: "bell"
        }
    }
    var hasDate: Bool { [.lesson, .homework, .assessment, .task, .reminder, .note, .behavior, .grade].contains(self) }
    var needsClass: Bool { [.student, .lesson, .homework, .assessment, .note, .behavior, .grade].contains(self) }
    var needsStudent: Bool { [.note, .behavior, .grade].contains(self) }
}

struct Entry: Identifiable, Codable, Hashable {
    var id = UUID()
    var kind: EntryKind
    var title: String
    var detail = ""
    var classID: UUID?
    var studentID: UUID?
    var subjectID: UUID?
    var categoryID: UUID?
    var assessmentID: UUID?
    var date = Date()
    var duration = 45
    var room = ""
    var objectives = ""
    var activities = ""
    var score: Double = 0
    var maximum: Double = 100
    var weight: Double = 1
    var status = "Planned"
    var archived = false
    var completed = false
    var submissions: [UUID] = []
    var fileName: String?
    var originalFileName: String?
    var createdAt = Date()
    static func suggestedDate(for kind: EntryKind, on day: Date = Date(), now: Date = Date(), calendar: Calendar = .current) -> Date {
        guard [.lesson, .homework, .assessment, .task, .reminder].contains(kind) else { return day }
        if calendar.isDate(day, inSameDayAs: now) { return calendar.dateInterval(of: .minute, for: now.addingTimeInterval(3600))?.start ?? now.addingTimeInterval(3600) }
        return calendar.date(bySettingHour: [.homework, .task].contains(kind) ? 17 : 9, minute: 0, second: 0, of: day) ?? day
    }
    var percentage: Double { maximum.isFinite && score.isFinite && maximum > 0 ? min(max(score / maximum * 100, 0), 100) : 0 }
}

enum Presence: String, Codable, CaseIterable { case present = "Present", absent = "Absent", late = "Late", excused = "Excused" }
struct AttendanceMark: Codable, Identifiable, Equatable {
    var id = UUID()
    var studentID: UUID
    var classID: UUID
    var date: Date
    var presence: Presence
}
struct Workspace: Codable, Equatable {
    var version = 1
    var clientID = UUID().uuidString
    var teacher = ""
    var entries: [Entry] = []
    var attendance: [AttendanceMark] = []
}

enum OrganizerFailure: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let message) = self { return message }; return nil }
}

@MainActor final class OrganizerStore: ObservableObject {
    @Published private(set) var workspace = Workspace()
    @Published private(set) var ready = false
    @Published private(set) var loadFailed = false
    @Published private(set) var sessionID = UUID()
    @Published var reminderRoute: UUID?
    @Published var incomingBackupURL: URL?
    @Published var error: String?
    @Published var notice: String?
    let directory: URL
    private let notificationsEnabled: Bool
    private var notificationBridge: ReminderNotificationBridge?
    private var reminderTask: Task<Void, Never>?
    static let maximumAttachmentBytes = 25 * 1024 * 1024
    static let maximumBackupBytes = 150 * 1024 * 1024
    var dataURL: URL { directory.appendingPathComponent("workspace.json") }

    init(directory customDirectory: URL? = nil, notificationsEnabled: Bool = true) {
        self.notificationsEnabled = notificationsEnabled
        directory = customDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("TeacherLessonOrganizer", isDirectory: true)
        if notificationsEnabled {
            notificationBridge = ReminderNotificationBridge { [weak self] id in self?.reminderRoute = id }
            UNUserNotificationCenter.current().delegate = notificationBridge
        }
    }
    func load() {
        error = nil
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var loaded = FileManager.default.fileExists(atPath: dataURL.path) ? try JSONDecoder().decode(Workspace.self, from: Data(contentsOf: dataURL)) : workspace
            if UUID(uuidString: loaded.clientID) == nil { loaded.clientID = UUID().uuidString }
            try Self.validate(loaded)
            try write(loaded)
            workspace = loaded; loadFailed = false
            cleanUnusedAttachments()
            synchronizeReminders()
        } catch { loadFailed = true; self.error = "Your workspace could not be opened. \(error.localizedDescription)" }
        ready = true
    }
    private func write(_ candidate: Workspace) throws {
        try Self.validate(candidate)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(candidate)
        #if os(iOS)
        try data.write(to: dataURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: dataURL, options: .atomic)
        #endif
    }
    @discardableResult private func commit(_ candidate: Workspace, recovering: Bool = false) -> Bool {
        error = nil
        guard !loadFailed || recovering else { error = "Restore or reopen the unreadable workspace before making changes."; return false }
        do { try write(candidate); workspace = candidate; loadFailed = false; return true }
        catch { self.error = "Changes could not be saved. \(error.localizedDescription)"; return false }
    }
    @discardableResult func persist() -> Bool { commit(workspace) }
    @discardableResult func setTeacher(_ name: String) -> Bool {
        var candidate = workspace; candidate.teacher = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return commit(candidate)
    }
    func items(_ kind: EntryKind, archived: Bool = false) -> [Entry] { workspace.entries.filter { $0.kind == kind && $0.archived == archived } }
    func entry(_ id: UUID?) -> Entry? { workspace.entries.first { $0.id == id } }
    func name(_ id: UUID?) -> String { entry(id)?.title ?? "Not assigned" }
    func choices(_ kind: EntryKind, including id: UUID? = nil) -> [Entry] { workspace.entries.filter { $0.kind == kind && (!$0.archived || $0.id == id) }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending } }
    func receivedCount(_ homework: Entry) -> Int {
        let students = Set(items(.student).filter { $0.classID == homework.classID }.map(\.id))
        return Set(homework.submissions).intersection(students).count
    }
    @discardableResult func save(_ record: Entry) -> Bool {
        var record = record
        record.title = record.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = entry(record.id)
        do {
            guard !record.title.isEmpty else { throw OrganizerFailure.invalid("Enter a title or name.") }
            if record.fileName != nil && fileURL(for: record) == nil { throw OrganizerFailure.invalid("The attachment is missing. Replace or remove it before saving.") }
            if record.kind == .assessment, let original, original.classID != record.classID, workspace.entries.contains(where: { $0.assessmentID == record.id }) { throw OrganizerFailure.invalid("This test already has results. Keep its class, or unlink its grades before moving it.") }
            if original == nil || original?.classID != record.classID {
                if record.kind.needsClass && record.classID == nil { throw OrganizerFailure.invalid("Choose a class first.") }
            }
            if record.kind.needsStudent && record.studentID == nil && (original == nil || original?.studentID != record.studentID) { throw OrganizerFailure.invalid("Choose a student first.") }
            if let student = entry(record.studentID), record.kind.needsStudent,
               (original == nil || original?.studentID != record.studentID || original?.classID != record.classID), student.classID != record.classID {
                throw OrganizerFailure.invalid("The selected student belongs to a different class.")
            }
            if let assessment = entry(record.assessmentID), assessment.classID != record.classID { throw OrganizerFailure.invalid("Choose a test from the selected class.") }
            if record.kind == .homework, let original, original.classID != record.classID { record.submissions = [] }
            var candidate = workspace
            if let index = candidate.entries.firstIndex(where: { $0.id == record.id }) { candidate.entries[index] = record }
            else { candidate.entries.append(record) }
            guard commit(candidate) else { return false }
            cleanUnusedAttachments()
            synchronizeReminders(requestPermission: record.kind == .reminder && !record.completed && !record.archived && record.date > Date())
            return true
        } catch { self.error = error.localizedDescription; return false }
    }
    @discardableResult func toggle(_ record: Entry) -> Bool { guard var current = entry(record.id) else { return false }; current.completed.toggle(); return save(current) }
    @discardableResult func archive(_ record: Entry) -> Bool { guard var current = entry(record.id) else { return false }; current.archived.toggle(); return save(current) }
    @discardableResult func delete(_ record: Entry) -> Bool {
        var candidate = workspace
        candidate.entries.removeAll { $0.id == record.id }
        for i in candidate.entries.indices {
            if candidate.entries[i].classID == record.id { candidate.entries[i].classID = nil }
            if candidate.entries[i].studentID == record.id { candidate.entries[i].studentID = nil }
            if candidate.entries[i].subjectID == record.id { candidate.entries[i].subjectID = nil }
            if candidate.entries[i].categoryID == record.id { candidate.entries[i].categoryID = nil }
            if candidate.entries[i].assessmentID == record.id { candidate.entries[i].assessmentID = nil }
            candidate.entries[i].submissions.removeAll { $0 == record.id }
        }
        candidate.attendance.removeAll { $0.studentID == record.id || $0.classID == record.id }
        guard commit(candidate) else { return false }
        cleanUnusedAttachments(); synchronizeReminders(); return true
    }
    func attendance(_ student: UUID, on date: Date) -> Presence? { workspace.attendance.first { $0.studentID == student && Calendar.current.isDate($0.date, inSameDayAs: date) }?.presence }
    @discardableResult func mark(_ student: Entry, on date: Date, as presence: Presence) -> Bool { markAll([student], on: date, as: presence) }
    @discardableResult func markAll(_ students: [Entry], on date: Date, as presence: Presence) -> Bool {
        guard Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date()) else { error = "Attendance can be recorded for today or a past day."; return false }
        var candidate = workspace
        for student in students {
            guard let current = entry(student.id), current.kind == .student, let classID = current.classID, entry(classID)?.kind == .classroom else { error = "Assign each student to a class before taking attendance."; return false }
            candidate.attendance.removeAll { $0.studentID == student.id && Calendar.current.isDate($0.date, inSameDayAs: date) }
            candidate.attendance.append(AttendanceMark(studentID: student.id, classID: classID, date: Calendar.current.startOfDay(for: date), presence: presence))
        }
        return commit(candidate)
    }
    @discardableResult func clearAttendance(studentID: UUID, on date: Date) -> Bool {
        var candidate = workspace
        candidate.attendance.removeAll { $0.studentID == studentID && Calendar.current.isDate($0.date, inSameDayAs: date) }
        return commit(candidate)
    }
    func weightedAverage(_ records: [Entry]) -> Double? {
        let grades = records.filter { $0.kind == .grade }
        let total = grades.reduce(0.0) { $0 + (entry($1.categoryID)?.weight ?? 1) }
        return total > 0 ? grades.reduce(0.0) { $0 + $1.percentage * (entry($1.categoryID)?.weight ?? 1) } / total : nil
    }
    func dailyAverages(_ records: [Entry], calendar: Calendar = .current) -> [LearningPoint] {
        let grades = records.filter { $0.kind == .grade }
        let groups = Dictionary(grouping: grades) { calendar.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { LearningPoint(date: $0, average: weightedAverage(groups[$0] ?? []) ?? 0) }
    }
    func average(studentID: UUID? = nil, classID: UUID? = nil) -> Double? {
        weightedAverage(items(.grade).filter { (studentID == nil || $0.studentID == studentID) && (classID == nil || $0.classID == classID) })
    }
    func importFile(_ url: URL, for item: inout Entry) throws {
        let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw OrganizerFailure.invalid("Choose a regular file, rather than a folder.") }
        guard (values.fileSize ?? 0) <= Self.maximumAttachmentBytes else { throw OrganizerFailure.invalid("Choose a file smaller than 25 MB.") }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let suffix = url.pathExtension.isEmpty ? "" : "." + url.pathExtension
        let name = UUID().uuidString + suffix
        try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(name))
        item.fileName = name; item.originalFileName = url.lastPathComponent
    }
    func fileURL(for record: Entry) -> URL? {
        guard let name = record.fileName, Self.validAttachmentName(name) else { return nil }
        let url = directory.appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    func discardUnreferencedFile(_ name: String?) {
        guard let name, Self.validAttachmentName(name), !workspace.entries.contains(where: { $0.fileName == name }) else { return }
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }
    private func cleanUnusedAttachments() {
        let used = Set(workspace.entries.compactMap(\.fileName))
        for url in (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [] where Self.validAttachmentName(url.lastPathComponent) && !used.contains(url.lastPathComponent) { try? FileManager.default.removeItem(at: url) }
    }
    func exportBackup() throws -> URL {
        guard !loadFailed else { throw OrganizerFailure.invalid("Reopen your workspace before exporting a backup.") }
        var files: [String: Data] = [:]
        var total = 0
        for record in workspace.entries {
            guard let name = record.fileName else { continue }
            guard let url = fileURL(for: record) else { throw OrganizerFailure.invalid("The attachment for ‘\(record.title)’ is missing. Replace or remove it before exporting.") }
            let data = try Data(contentsOf: url, options: .mappedIfSafe); total += data.count
            guard total <= 100 * 1024 * 1024 else { throw OrganizerFailure.invalid("This workspace has more than 100 MB of attachments. Remove unused materials before exporting.") }
            files[name] = data
        }
        let data = try JSONEncoder().encode(Backup(workspace: workspace, files: files))
        guard data.count <= Self.maximumBackupBytes else { throw OrganizerFailure.invalid("The backup exceeds the 150 MB limit.") }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Teacher-Workspace-\(UUID().uuidString.prefix(8)).teacherbackup")
        try data.write(to: url, options: .atomic); return url
    }
    func stageBackup(_ url: URL) throws -> URL {
        guard url.isFileURL else { throw OrganizerFailure.invalid("Choose a local backup file.") }
        let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw OrganizerFailure.invalid("Choose a backup file, rather than a folder.") }
        guard (values.fileSize ?? 0) <= Self.maximumBackupBytes else { throw OrganizerFailure.invalid("Choose a backup smaller than 150 MB.") }
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("Incoming-" + UUID().uuidString + ".teacherbackup")
        try FileManager.default.copyItem(at: url, to: copy)
        return copy
    }
    func discardBackupImport(_ url: URL?) {
        guard let url, url.deletingLastPathComponent().resolvingSymlinksInPath() == FileManager.default.temporaryDirectory.resolvingSymlinksInPath(), url.lastPathComponent.hasPrefix("Incoming-"), url.pathExtension == "teacherbackup" else { return }
        try? FileManager.default.removeItem(at: url)
    }
    func receiveBackup(_ url: URL) {
        do { let copy = try stageBackup(url); dismissIncomingBackup(); incomingBackupURL = copy }
        catch { self.error = "The backup could not be opened. \(error.localizedDescription)" }
    }
    func dismissIncomingBackup() { discardBackupImport(incomingBackupURL); incomingBackupURL = nil }
    func restore(_ url: URL) throws {
        let granted = url.startAccessingSecurityScopedResource(); defer { if granted { url.stopAccessingSecurityScopedResource() } }
        guard (try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) <= Self.maximumBackupBytes else { throw OrganizerFailure.invalid("Choose a backup smaller than 150 MB.") }
        let backup = try JSONDecoder().decode(Backup.self, from: Data(contentsOf: url, options: .mappedIfSafe))
        var restored = backup.workspace; restored.clientID = workspace.clientID
        try Self.validate(restored)
        let names = Set(backup.workspace.entries.compactMap(\.fileName))
        guard Set(backup.files.keys) == names, backup.files.values.allSatisfy({ $0.count <= Self.maximumAttachmentBytes }) else { throw OrganizerFailure.invalid("This backup contains missing or invalid attachments.") }
        var written: [URL] = []
        var replacements: [String: String] = [:]
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            for (name, data) in backup.files {
                let suffix = URL(fileURLWithPath: name).pathExtension
                let newName = UUID().uuidString + (suffix.isEmpty ? "" : "." + suffix)
                let destination = directory.appendingPathComponent(newName)
                try data.write(to: destination, options: .atomic); written.append(destination); replacements[name] = newName
            }
            for index in restored.entries.indices { if let old = restored.entries[index].fileName { restored.entries[index].fileName = replacements[old] } }
            guard commit(restored, recovering: true) else { throw OrganizerFailure.invalid(error ?? "The backup could not be saved.") }
        } catch { for file in written { try? FileManager.default.removeItem(at: file) }; throw error }
        sessionID = UUID(); reminderRoute = nil; cleanUnusedAttachments(); synchronizeReminders()
        notice = "Workspace restored. Future reminders will alert if notifications are enabled on this device."
    }
    @discardableResult func reset() -> Bool {
        let candidate = Workspace(clientID: workspace.clientID)
        guard commit(candidate, recovering: true) else { return false }
        sessionID = UUID(); reminderRoute = nil; cleanUnusedAttachments(); synchronizeReminders(); return true
    }
    func reminderPlan(now: Date = Date()) -> [Entry] {
        Array(items(.reminder).filter { !$0.completed && $0.date > now }.sorted { $0.date < $1.date }.prefix(64))
    }
    func synchronizeReminders(requestPermission: Bool = false) {
        guard notificationsEnabled, !loadFailed else { return }
        let previous = reminderTask
        previous?.cancel()
        reminderTask = Task { [weak self] in
            await previous?.value
            guard let self, !Task.isCancelled else { return }
            let center = UNUserNotificationCenter.current()
            do {
                var settings = await center.notificationSettings()
                if requestPermission && settings.authorizationStatus == .notDetermined {
                    _ = try await center.requestAuthorization(options: [.alert, .sound, .badge]); settings = await center.notificationSettings()
                }
                guard !Task.isCancelled else { return }
                center.removeAllPendingNotificationRequests()
                guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                    if requestPermission { self.notice = "Reminder saved. Enable notifications for Teacher Lesson Organizer in iOS Settings to receive alerts." }; return
                }
                let future = self.items(.reminder).filter { !$0.completed && $0.date > Date() }.sorted { $0.date < $1.date }
                for item in self.reminderPlan() {
                    guard !Task.isCancelled else { return }
                    let content = UNMutableNotificationContent(); content.title = item.title; content.body = item.detail; content.sound = .default; content.userInfo = ["entryID": item.id.uuidString]
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: item.date)
                    try await center.add(UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
                }
                if requestPermission && future.count > 64 { self.notice = "Reminder saved. iOS schedules the next 64 reminders; later reminders are scheduled when you reopen the app." }
            } catch { if !Task.isCancelled { self.error = "Notifications could not be updated. \(error.localizedDescription)" } }
        }
    }
    static func validAttachmentName(_ name: String) -> Bool {
        guard !name.contains("/"), !name.contains("\\"), name.count <= 160 else { return false }
        return UUID(uuidString: String(name.prefix(36))) != nil && (name.count == 36 || name.dropFirst(36).first == ".")
    }
    static func validate(_ candidate: Workspace) throws {
        guard candidate.version == 1, UUID(uuidString: candidate.clientID) != nil else { throw OrganizerFailure.invalid("Unsupported or invalid workspace format.") }
        let ids = candidate.entries.map(\.id)
        guard Set(ids).count == ids.count else { throw OrganizerFailure.invalid("The workspace contains duplicate records.") }
        let lookup = Dictionary(uniqueKeysWithValues: candidate.entries.map { ($0.id, $0) })
        for record in candidate.entries {
            guard !record.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, record.date.timeIntervalSinceReferenceDate.isFinite, record.createdAt.timeIntervalSinceReferenceDate.isFinite, (Date.distantPast...Date.distantFuture).contains(record.date), (Date.distantPast...Date.distantFuture).contains(record.createdAt) else { throw OrganizerFailure.invalid("A record has an invalid name or date.") }
            for (id, kind) in [(record.classID, EntryKind.classroom), (record.studentID, .student), (record.subjectID, .subject), (record.categoryID, .category), (record.assessmentID, .assessment)] {
                if let id, lookup[id]?.kind != kind { throw OrganizerFailure.invalid("A record contains an invalid connection.") }
            }
            guard record.score.isFinite, record.maximum.isFinite, record.weight.isFinite else { throw OrganizerFailure.invalid("Scores and weights must be valid numbers.") }
            if record.kind == .grade || record.kind == .assessment { guard record.maximum > 0, record.score >= 0, record.score <= record.maximum else { throw OrganizerFailure.invalid("Enter a score between zero and a positive maximum.") } }
            if record.kind == .category { guard (0.5...10).contains(record.weight) else { throw OrganizerFailure.invalid("Category weights must be between 0.5 and 10.") } }
            if record.kind == .lesson || record.kind == .template { guard (5...360).contains(record.duration) else { throw OrganizerFailure.invalid("Lesson duration must be between 5 and 360 minutes.") } }
            if let file = record.fileName, !validAttachmentName(file) { throw OrganizerFailure.invalid("An attachment has an invalid filename.") }
            guard Set(record.submissions).count == record.submissions.count, record.submissions.allSatisfy({ lookup[$0]?.kind == .student }) else { throw OrganizerFailure.invalid("A submission is linked to an invalid student.") }
        }
        guard Set(candidate.attendance.map(\.id)).count == candidate.attendance.count else { throw OrganizerFailure.invalid("The workspace contains duplicate attendance identifiers.") }
        var days = Set<String>()
        for mark in candidate.attendance {
            guard lookup[mark.studentID]?.kind == .student, lookup[mark.classID]?.kind == .classroom, mark.date.timeIntervalSinceReferenceDate.isFinite, (Date.distantPast...Date.distantFuture).contains(mark.date) else { throw OrganizerFailure.invalid("An attendance record has an invalid connection or date.") }
            let key = mark.studentID.uuidString + String(Calendar.current.startOfDay(for: mark.date).timeIntervalSinceReferenceDate)
            guard days.insert(key).inserted else { throw OrganizerFailure.invalid("The workspace contains duplicate attendance marks for one day.") }
        }
    }
    @discardableResult func loadSample() -> Bool {
        guard workspace.entries.isEmpty else { notice = "Sample data is available only in an empty workspace."; return false }
        var sample = Workspace(clientID: workspace.clientID, teacher: workspace.teacher)
        let cal = Calendar.current
        func day(_ offset: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: cal.date(byAdding: .day, value: offset, to: Date())!)!
        }
        let c1 = Entry(kind: .classroom, title: "Year 8 · Oak", detail: "A curious group of growing thinkers.", room: "Room 204")
        let c2 = Entry(kind: .classroom, title: "Year 9 · Maple", detail: "Building confidence through discovery.", room: "Room 208")
        let subject = Entry(kind: .subject, title: "English literature", detail: "Reading deeply. Writing with purpose.")
        let subject2 = Entry(kind: .subject, title: "Creative writing", detail: "Making space for original voices.")
        sample.entries = [c1, c2, subject, subject2]
        for (i, name) in ["Amelia Brooks", "Oliver Chen", "Isla Bennett", "Noah Williams", "Mia Patel", "Leo Thompson", "Sofia Rivera", "Ethan Clarke"].enumerated() {
            sample.entries.append(Entry(kind: .student, title: name, detail: "", classID: i < 5 ? c1.id : c2.id))
        }
        let lessons = [Entry(kind: .lesson, title: "The art of storytelling", detail: "Explore how a strong opening draws a reader in.", classID: c1.id, subjectID: subject.id, date: day(0, 9), room: "204", objectives: "Identify narrative voice and setting.\nWrite an engaging opening paragraph.", activities: "5 min · Opening prompt\n15 min · Read and discuss\n20 min · Independent writing\n5 min · Exit reflection"), Entry(kind: .lesson, title: "Finding your voice", detail: "A workshop in personal expression.", classID: c2.id, subjectID: subject2.id, date: day(0, 11, 30), room: "208", objectives: "Experiment with tone and perspective.", activities: "Warm-up, paired feedback, revision."), Entry(kind: .lesson, title: "Poetry in everyday life", classID: c1.id, subjectID: subject.id, date: day(1, 10), room: "204")]
        sample.entries += lessons
        sample.entries += [Entry(kind: .homework, title: "A story worth telling", detail: "Write a 400-word story inspired by an everyday moment. Include a clear setting and a distinctive narrative voice.", classID: c1.id, subjectID: subject.id, date: day(2, 16)), Entry(kind: .assessment, title: "Narrative techniques quiz", detail: "Ten short questions on character, setting and perspective.", classID: c1.id, subjectID: subject.id, date: day(3, 9)), Entry(kind: .task, title: "Prepare poetry handouts", detail: "Choose three contrasting poems for tomorrow.", date: day(0, 17)), Entry(kind: .task, title: "Review writing portfolios", date: day(1, 16)), Entry(kind: .template, title: "Reading workshop", objectives: "Read critically and support ideas with evidence.", activities: "Opening question · 5 min\nClose reading · 15 min\nDiscussion · 15 min\nReflection · 10 min"), Entry(kind: .category, title: "Classwork", detail: "Everyday learning and participation.", weight: 1), Entry(kind: .category, title: "Assessments", detail: "Tests, quizzes and extended work.", weight: 2), Entry(kind: .material, title: "Narrative writing prompts", detail: "1. A letter arrives twenty years late.\n2. A familiar street looks different today.\n3. An ordinary object tells its story.", subjectID: subject2.id)]
        for (i, student) in sample.entries.filter({ $0.kind == .student }).enumerated() {
            for offset in [-14, -7, -1] {
                sample.entries.append(Entry(kind: .grade, title: "Writing reflection", classID: student.classID, studentID: student.id, categoryID: sample.entries.first(where: { $0.kind == .category })?.id, date: day(offset, 12), score: Double(68 + (i * 7 + offset + 14) % 29)))
                sample.attendance.append(AttendanceMark(studentID: student.id, classID: student.classID!, date: day(offset, 9), presence: i == 2 && offset == -7 ? .absent : .present))
            }
        }
        if let student = sample.entries.first(where: { $0.kind == .student }) {
            sample.entries.append(Entry(kind: .note, title: "Growing confidence", detail: "Amelia volunteered to read aloud today. Offer another opportunity in the next workshop.", classID: c1.id, studentID: student.id))
        }
        return commit(sample)
    }}
struct Backup: Codable { var workspace: Workspace; var files: [String: Data] }

@MainActor final class ReminderNotificationBridge: NSObject, UNUserNotificationCenterDelegate {
    let open: (UUID) -> Void
    init(open: @escaping (UUID) -> Void) { self.open = open }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([.banner, .sound]) }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let raw = response.notification.request.content.userInfo["entryID"] as? String, let id = UUID(uuidString: raw) { Task { @MainActor in self.open(id) } }
        completionHandler()
    }
}

struct LearningPoint: Identifiable {
    var date: Date
    var average: Double
    var id: Date { date }
}
