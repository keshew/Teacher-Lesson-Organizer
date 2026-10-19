import Foundation

@main struct ReleaseChecks {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("TeacherReleaseChecks-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        var checks = 0
        func check(_ condition: Bool, _ name: String) { precondition(condition, name); checks += 1 }
        let store = OrganizerStore(directory: root.appendingPathComponent("Main"), notificationsEnabled: false)
        store.load()
        let classroom = Entry(kind: .classroom, title: "Oak")
        let secondClass = Entry(kind: .classroom, title: "Maple")
        let student = Entry(kind: .student, title: "Avery", classID: classroom.id)
        let subject = Entry(kind: .subject, title: "English")
        let category = Entry(kind: .category, title: "Practice", weight: 0.5)
        let assessment = Entry(kind: .assessment, title: "Quiz", classID: classroom.id, maximum: 20)
        for entry in [classroom, secondClass, student, subject, category, assessment] { check(store.save(entry), "Save prerequisite") }
        for kind in EntryKind.allCases {
            var record = Entry(kind: kind, title: "New \(kind.rawValue)", classID: kind.needsClass ? classroom.id : nil, studentID: kind.needsStudent ? student.id : nil)
            check(store.save(record), "Create \(kind)")
            record.title += " edited"
            check(store.save(record) && store.entry(record.id)?.title == record.title, "Edit \(kind)")
            check(store.archive(record) && store.entry(record.id)?.archived == true, "Archive \(kind)")
            check(store.archive(record) && store.entry(record.id)?.archived == false, "Restore \(kind)")
            if [.lesson, .homework, .assessment, .task, .reminder].contains(kind) {
                check(store.toggle(record) && store.entry(record.id)?.completed == true, "Complete \(kind)")
                check(store.toggle(record) && store.entry(record.id)?.completed == false, "Reopen \(kind)")
            }
            check(store.delete(record) && store.entry(record.id) == nil, "Delete \(kind)")
        }
        let beforeInvalid = store.workspace
        check(!store.save(Entry(kind: .student, title: "Missing class")), "Reject missing class")
        check(!store.save(Entry(kind: .note, title: "Missing student", classID: classroom.id)), "Reject missing student")
        check(!store.save(Entry(kind: .grade, title: "Wrong class", classID: secondClass.id, studentID: student.id)), "Reject mismatched student")
        check(!store.save(Entry(kind: .grade, title: "Wrong test", classID: classroom.id, studentID: student.id, assessmentID: subject.id)), "Reject non-test assessment connection")
        check(!store.save(Entry(kind: .category, title: "Bad weight", weight: 0)), "Reject zero weight")
        check(!store.save(Entry(kind: .grade, title: "Bad score", classID: classroom.id, studentID: student.id, score: 101)), "Reject score over maximum")
        check(!store.save(Entry(kind: .grade, title: "Bad max", classID: classroom.id, studentID: student.id, maximum: 0)), "Reject zero maximum")
        check(!store.save(Entry(kind: .lesson, title: "Bad duration", classID: classroom.id, duration: 0)), "Reject zero duration")
        check(!store.save(Entry(kind: .task, title: "  \n ")), "Reject blank title")
        check(store.workspace == beforeInvalid, "Invalid changes leave workspace unchanged")
        let day = Calendar.current.startOfDay(for: Date()).addingTimeInterval(9 * 3600)
        let gradeA = Entry(kind: .grade, title: "Practice", classID: classroom.id, studentID: student.id, categoryID: category.id, date: day, score: 80)
        let gradeB = Entry(kind: .grade, title: "Quiz", classID: classroom.id, studentID: student.id, assessmentID: assessment.id, date: day.addingTimeInterval(3600), score: 10, maximum: 20)
        check(store.save(gradeA) && store.save(gradeB), "Save linked grades")
        check(abs((store.average(studentID: student.id) ?? 0) - 60) < 0.0001, "Fractional category weight")
        check(store.dailyAverages([gradeA]).first?.average == 80, "One half-weight record keeps its actual percentage")
        check(store.dailyAverages([gradeA, gradeB]).count == 1 && store.dailyAverages([gradeA, gradeB]).first?.average == 60, "Daily aggregation")
        var movedTest = assessment; movedTest.classID = secondClass.id
        check(!store.save(movedTest), "Prevent moving a test with results to another class")
        var homework = Entry(kind: .homework, title: "Reading", classID: classroom.id, submissions: [student.id])
        check(store.save(homework) && store.receivedCount(homework) == 1, "Track homework submission")
        homework.classID = secondClass.id
        check(store.save(homework) && store.entry(homework.id)?.submissions.isEmpty == true, "Reassign homework without stale submissions")
        check(store.markAll([student], on: Date(), as: .present), "Bulk attendance")
        check(store.mark(student, on: Date(), as: .late) && store.workspace.attendance.count == 1, "Update one daily attendance mark")
        check(store.clearAttendance(studentID: student.id, on: Date()) && store.workspace.attendance.isEmpty, "Clear accidental attendance")
        check(!store.mark(student, on: Date().addingTimeInterval(86400 * 2), as: .present), "Reject future attendance")
        let resource = root.appendingPathComponent("handout.txt")
        try Data("Original handout".utf8).write(to: resource)
        var material = Entry(kind: .material, title: "Handout")
        try store.importFile(resource, for: &material)
        check(store.save(material), "Save local attachment")
        let oldURL = store.fileURL(for: material)!
        let replacementSource = root.appendingPathComponent("replacement.txt")
        try Data("New handout".utf8).write(to: replacementSource)
        var draft = material
        try store.importFile(replacementSource, for: &draft)
        check(FileManager.default.fileExists(atPath: oldURL.path), "Selecting a replacement preserves saved attachment")
        store.discardUnreferencedFile(draft.fileName)
        check(store.fileURL(for: material) != nil && store.fileURL(for: draft) == nil, "Discard draft attachment without touching saved file")
        try store.importFile(replacementSource, for: &draft)
        let beforeFailure = store.workspace
        let diskBytes = try Data(contentsOf: store.dataURL)
        try FileManager.default.removeItem(at: store.dataURL)
        try FileManager.default.createDirectory(at: store.dataURL, withIntermediateDirectories: true)
        check(!store.save(draft) && store.workspace == beforeFailure, "Failed disk write rolls back memory")
        check(FileManager.default.fileExists(atPath: oldURL.path), "Failed replacement preserves old file")
        check(!store.delete(material) && store.workspace == beforeFailure && store.fileURL(for: material) != nil, "Failed delete preserves record and file")
        let backup = try store.exportBackup()
        let filesBeforeRestoreFailure = Set(try FileManager.default.contentsOfDirectory(atPath: store.directory.path))
        do { try store.restore(backup); preconditionFailure("Restore should fail on blocked destination") } catch { }
        check(store.workspace == beforeFailure, "Failed restore preserves memory")
        check(Set(try FileManager.default.contentsOfDirectory(atPath: store.directory.path)) == filesBeforeRestoreFailure, "Failed restore removes all staged files")
        try FileManager.default.removeItem(at: store.dataURL)
        try diskBytes.write(to: store.dataURL)
        store.discardUnreferencedFile(draft.fileName)
        try store.importFile(replacementSource, for: &draft)
        check(store.save(draft) && !FileManager.default.fileExists(atPath: oldURL.path), "Successful replacement removes old file only after commit")
        check(store.setTeacher("  Morgan  ") && store.workspace.teacher == "Morgan", "Profile persistence")
        let target = OrganizerStore(directory: root.appendingPathComponent("Restored"), notificationsEnabled: false)
        target.load(); let localID = target.workspace.clientID
        let newBackup = try store.exportBackup()
        let staged = try target.stageBackup(newBackup)
        let originalBackupBytes = try Data(contentsOf: newBackup)
        let stagedBackupBytes = try Data(contentsOf: staged)
        check(originalBackupBytes == stagedBackupBytes, "Stage import before asking for confirmation")
        target.discardBackupImport(staged)
        check(!FileManager.default.fileExists(atPath: staged.path) && FileManager.default.fileExists(atPath: newBackup.path), "Cancel import keeps original backup")
        target.receiveBackup(newBackup)
        check(target.incomingBackupURL != nil, "Open-in backup waits for user confirmation")
        target.dismissIncomingBackup()
        check(target.incomingBackupURL == nil && FileManager.default.fileExists(atPath: newBackup.path), "Cancel Open-in is non-destructive")
        do { _ = try target.stageBackup(root); preconditionFailure("Folder accepted as backup") } catch { checks += 1 }
        try target.restore(newBackup)
        check(target.workspace.clientID == localID && localID != store.workspace.clientID, "Restore preserves installation ID")
        let restoredFile = try Data(contentsOf: target.fileURL(for: target.entry(material.id)!)!)
        check(restoredFile == Data("New handout".utf8), "Backup restores exact attachment contents")
        check(target.workspace.entries.count == store.workspace.entries.count, "Backup restores every record")
        check(target.delete(student) && target.items(.grade).allSatisfy { $0.studentID == nil }, "Deleting student preserves historical grades")
        check(target.archive(target.entry(gradeA.id)!), "Orphaned history can still be archived")
        let client = target.workspace.clientID
        check(target.reset() && target.workspace.entries.isEmpty && target.workspace.clientID == client, "Reset retains generated device ID")
        let countBeforeBadRestore = target.workspace.entries.count
        let unsafe = root.appendingPathComponent("unsafe.teacherbackup")
        let malicious = Backup(workspace: Workspace(entries: [Entry(kind: .material, title: "Unsafe", fileName: "workspace.json")]), files: ["workspace.json": Data("bad".utf8)])
        try JSONEncoder().encode(malicious).write(to: unsafe)
        do { try target.restore(unsafe); preconditionFailure("Unsafe backup accepted") } catch { }
        check(target.workspace.entries.count == countBeforeBadRestore, "Reserved attachment name cannot overwrite workspace")
        let future = Date().addingTimeInterval(3600)
        for index in (0..<70).reversed() { check(target.save(Entry(kind: .reminder, title: "Reminder \(index)", date: future.addingTimeInterval(Double(index) * 60))), "Create scheduled reminder") }
        check(target.reminderPlan().count == 64, "Respect 64-notification limit")
        check(target.reminderPlan().first?.title == "Reminder 0" && target.reminderPlan().last?.title == "Reminder 63", "Schedule nearest reminders in order")
        let firstReminder = target.reminderPlan().first!
        check(target.toggle(firstReminder) && !target.reminderPlan().contains { $0.id == firstReminder.id }, "Completed reminder removed from notification plan")
        let nextReminder = target.reminderPlan().first!
        check(target.archive(nextReminder) && !target.reminderPlan().contains { $0.id == nextReminder.id }, "Archived reminder removed from notification plan")
        check(Entry.suggestedDate(for: .reminder, on: Date()) > Date(), "Future default reminder date")
        let sample = OrganizerStore(directory: root.appendingPathComponent("Sample"), notificationsEnabled: false)
        sample.load(); check(sample.loadSample(), "Sample workspace creates valid linked data")
        check(!sample.items(.classroom).isEmpty && !sample.items(.student).isEmpty && sample.average() != nil, "Sample workspace is functional")
        let reopened = OrganizerStore(directory: target.directory, notificationsEnabled: false)
        reopened.load(); check(!reopened.loadFailed && reopened.workspace == target.workspace, "Full workspace survives relaunch")
        print("PASS: \(checks) release checks across all record types, persistence failures, attachments, backup transactions, grades, attendance, reminders and sample data")
    }
}
