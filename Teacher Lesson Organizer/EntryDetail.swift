import SwiftUI
import QuickLook

struct EntryDetailView: View {
    @EnvironmentObject var store: OrganizerStore
    @Environment(\.dismiss) var dismiss
    var id: UUID
    @State private var editing = false
    @State private var create: EntryKind?
    @State private var draftLesson: Entry?
    @State private var deleting = false
    @State private var preview: URL?
    var entry: Entry? { store.entry(id) }
    var body: some View {
        Group {
            if let entry {
                Page {
                    detailHeader(entry)
                    if entry.archived || entry.completed { HStack { if entry.archived { StatusPill(text: "Archived", color: .gold) }; if entry.completed { StatusPill(text: "Completed") }; Spacer() } }
                    if entry.kind == .classroom { classContent(entry) }
                    else if entry.kind == .student { studentContent(entry) }
                    else { recordContent(entry) }
                    if !entry.detail.isEmpty { textCard(entry.kind == .homework ? "Instructions" : "Notes & context", text: entry.detail) }
                    if [.lesson, .template].contains(entry.kind) {
                        textCard("Learning objectives", text: entry.objectives.isEmpty ? "Add the learning goals for this lesson." : entry.objectives)
                        textCard("Activities & timing", text: entry.activities.isEmpty ? "Outline your teaching sequence and activities." : entry.activities)
                    }
                    if entry.kind == .homework { submissions(entry) }
                    if entry.kind == .assessment { assessmentContent(entry) }
                    if entry.kind == .subject { related("Lessons", items: store.items(.lesson).filter { $0.subjectID == id }); related("Materials", items: store.items(.material).filter { $0.subjectID == id }) }
                    if entry.kind == .category { related("Grades in this category", items: store.items(.grade).filter { $0.categoryID == id }) }
                    if entry.fileName != nil {
                        if let url = store.fileURL(for: entry) {
                            Button { preview = url } label: { PaperCard { Label(entry.originalFileName ?? "Open attachment", systemImage: "paperclip").font(.subheadline) } }
                            ShareLink(item: url) { Label("Share attachment", systemImage: "square.and.arrow.up").font(.subheadline) }
                        } else {
                            PaperCard { VStack(alignment: .leading, spacing: 12) { Label("Attachment unavailable", systemImage: "exclamationmark.triangle").foregroundStyle(Color.gold); Text("Replace or remove this file using Edit.").font(.caption).foregroundStyle(Color.secondaryInk); Button("Edit attachment") { editing = true } } }
                        }
                    }
                    actions(entry)
                }
                .navigationTitle(entry.kind.singular).navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editing = true } label: { Label("Edit", systemImage: "pencil").font(.system(size: 11, weight: .medium)) } } }
                .sheet(item: $draftLesson) { EntryEditor(kind: .lesson, entry: $0, creating: true) }
                .sheet(isPresented: $editing) { EntryEditor(kind: entry.kind, entry: entry) }
                .sheet(item: $create) { kind in
                    EntryEditor(kind: kind, classID: entry.kind == .classroom ? entry.id : entry.classID, studentID: entry.kind == .student ? entry.id : nil, assessmentID: entry.kind == .assessment ? entry.id : nil, requiresAssessment: entry.kind == .assessment)
                }
                .confirmationDialog("Delete this \(entry.kind.singular.lowercased())? Linked records will be kept without this connection.", isPresented: $deleting, titleVisibility: .visible) {
                    Button("Delete permanently", role: .destructive) { if store.delete(entry) { dismiss() } }
                    Button("Cancel", role: .cancel) { }
                }
            } else { EmptyCard(icon: "doc", title: "Record unavailable", message: "This entry may have been deleted.") }
        }.quickLookPreview($preview)
    }
    func detailHeader(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack {
                Kicker(text: entry.kind == .student ? "Student portfolio" : entry.kind == .classroom ? "Class portfolio" : entry.kind.singular, color: .champagne)
                Spacer()
                if entry.kind == .student { Avatar(name: entry.title, size: 54, dark: true) }
                else { Image(systemName: entry.kind.icon).font(.system(size: 30, weight: .ultraLight)).foregroundStyle(Color.champagne.opacity(0.8)) }
            }
            Text(entry.title).font(.system(size: 36, design: .serif)).tracking(-1).foregroundStyle(Color.paper).fixedSize(horizontal: false, vertical: true)
            Rectangle().fill(.white.opacity(0.12)).frame(height: 0.6)
            HStack(spacing: 8) {
                if entry.kind == .student { Image(systemName: "rectangle.3.group"); Text(store.name(entry.classID)) }
                else if entry.kind.hasDate { Image(systemName: "calendar"); Text(entry.date.formatted(.dateTime.month(.wide).day().year())) }
                else { Text(entry.room.isEmpty ? "PERSONAL TEACHING COLLECTION" : entry.room).tracking(1.3) }
                Spacer()
                Image(systemName: "lock").font(.system(size: 9))
            }.font(.system(size: 9)).foregroundStyle(Color.paper.opacity(0.5))
        }.padding(25).navySurface()
    }
    func textCard(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionLabel(title: title)
            PaperCard {
                if title == "Activities & timing" || title == "Learning objectives" {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(text.split(separator: "\n").enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 14) {
                                if title == "Activities & timing" { Text(String(format: "%02d", index + 1)).font(.system(size: 13, design: .serif)).foregroundStyle(Color.gold).frame(width: 24, height: 25).background(Color.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 7)) }
                                else { Image(systemName: "checkmark").font(.system(size: 10, weight: .light)).foregroundStyle(Color.gold).frame(width: 22, height: 23).background(Color.gold.opacity(0.08), in: Circle()) }
                                Text(String(line)).font(.system(size: 13)).lineSpacing(6).foregroundStyle(Color.secondaryInk).textSelection(.enabled)
                            }
                        }
                    }
                } else { Text(text).font(.system(size: 13)).lineSpacing(8).foregroundStyle(Color.secondaryInk).textSelection(.enabled) }
            }
        }
    }
    func related(_ title: String, items: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(title: title, caption: "\(items.count)")
            if items.isEmpty { HStack { Image(systemName: "minus").foregroundStyle(Color.gold); Text("No records in this collection yet.").font(.system(size: 11)).foregroundStyle(Color.secondaryInk); Spacer() }.padding(17).background(.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 15)) }
            else { PaperCard { VStack(spacing: 12) { ForEach(items.sorted { $0.date > $1.date }) { item in NavigationLink(value: item) { EntryRow(entry: item) }.buttonStyle(.plain) } } } }
        }
    }
    func classContent(_ entry: Entry) -> some View {
        VStack(spacing: 22) {
            HStack(spacing: 12) { StatTile(value: "\(store.items(.student).filter { $0.classID == id }.count)", label: "Students", icon: "person.2"); StatTile(value: store.average(classID: id).map { "\(Int($0))%" } ?? "—", label: "Weighted average", icon: "chart.bar") }
            if !entry.room.isEmpty { PaperCard { Label(entry.room, systemImage: "door.left.hand.open").font(.subheadline) } }
            HStack(spacing: 12) {
                NavigationLink(value: ContextRoute.attendance(id, Date())) { Label("Attendance", systemImage: "person.badge.clock") }
                Spacer()
                Button("Add student", systemImage: "plus") { create = .student }
            }.font(.caption.weight(.semibold))
            related("Class roster", items: store.items(.student).filter { $0.classID == id })
            related("Lesson plans", items: store.items(.lesson).filter { $0.classID == id })
            Button("Plan a lesson", systemImage: "plus") { create = .lesson }.buttonStyle(GoldButton())
            related("Homework", items: store.items(.homework).filter { $0.classID == id })
            Button("Assign homework", systemImage: "tray.and.arrow.up") { create = .homework }.font(.subheadline)
            NavigationLink(value: ContextRoute.progress(.classProgress, id)) { Label("Explore class progress", systemImage: "chart.xyaxis.line") }.font(.subheadline)
        }
    }
    func studentContent(_ entry: Entry) -> some View {
        VStack(spacing: 22) {
            HStack(spacing: 12) { StatTile(value: store.average(studentID: id).map { "\(Int($0))%" } ?? "—", label: "Weighted average", icon: "chart.bar"); StatTile(value: "\(store.workspace.attendance.filter { $0.studentID == id && $0.presence == .present }.count)", label: "Days present", icon: "checkmark.circle") }
            if let classroom = store.entry(entry.classID) { NavigationLink(value: classroom) { PaperCard { EntryRow(entry: classroom) } } }
            HStack { Button("Add note", systemImage: "note.text.badge.plus") { create = .note }; Spacer(); Button("Record grade", systemImage: "plus") { create = .grade } }.font(.caption.weight(.semibold))
            related("Learning record", items: store.items(.grade).filter { $0.studentID == id })
            related("Student notes", items: store.items(.note).filter { $0.studentID == id })
            related("Behavior observations", items: store.items(.behavior).filter { $0.studentID == id })
            Button("Add behavior observation", systemImage: "hand.thumbsup") { create = .behavior }.font(.subheadline)
            NavigationLink(value: ContextRoute.progress(.studentProgress, id)) { Label("Explore student progress", systemImage: "chart.xyaxis.line") }.font(.subheadline)
        }
    }
    func recordContent(_ entry: Entry) -> some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 16) {
                if let classroom = store.entry(entry.classID) { NavigationLink(value: classroom) { Label(classroom.title, systemImage: "rectangle.3.group") } }
                if let student = store.entry(entry.studentID) { NavigationLink(value: student) { Label(student.title, systemImage: "person") } }
                if let subject = store.entry(entry.subjectID) { NavigationLink(value: subject) { Label(subject.title, systemImage: "books.vertical") } }
                if entry.kind == .lesson {
                    Label("\(entry.date.formatted(date: .omitted, time: .shortened)) · \(entry.duration) minutes", systemImage: "clock")
                    if !entry.room.isEmpty { Label(entry.room, systemImage: "door.left.hand.open") }
                    NavigationLink(value: ContextRoute.attendance(entry.classID, entry.date)) { Label("Take attendance for this day", systemImage: "person.badge.clock") }
                }
                if entry.kind == .grade { Text("\(entry.score.formatted()) / \(entry.maximum.formatted())").font(.system(size: 43, design: .serif)).foregroundStyle(Color.ink); StatusPill(text: "\(Int(entry.percentage))% · \(store.entry(entry.categoryID)?.title ?? "Uncategorized")") }
                if entry.kind == .category { Text("Grade weight ×\(entry.weight.formatted())").font(.system(size: 22, design: .serif)) }
                if [.behavior, .lesson].contains(entry.kind) { StatusPill(text: entry.status) }
                if entry.classID == nil && entry.subjectID == nil && ![.lesson, .grade, .category, .behavior].contains(entry.kind) { Label(entry.kind.singular, systemImage: entry.kind.icon).foregroundStyle(Color.gold) }
            }.font(.subheadline).foregroundStyle(Color.secondaryInk)
        }
    }
    func submissions(_ entry: Entry) -> some View {
        let students = store.items(.student).filter { $0.classID == entry.classID }
        return VStack(alignment: .leading, spacing: 13) {
            SectionLabel(title: "Submission tracker", caption: "\(entry.submissions.filter { id in students.contains { $0.id == id } }.count)/\(students.count)")
            Text("Tap a student to mark work as received.").font(.caption).foregroundStyle(Color.secondaryInk)
            PaperCard { VStack(spacing: 16) {
                if students.isEmpty { Text("Add students to this class first.").font(.subheadline).foregroundStyle(Color.secondaryInk) }
                ForEach(students) { student in Button { var e = entry; if e.submissions.contains(student.id) { e.submissions.removeAll { $0 == student.id } } else { e.submissions.append(student.id) }; withAnimation { _ = store.save(e) } } label: { HStack(spacing: 12) { Avatar(name: student.title, size: 35); Text(student.title).font(.system(size: 13)); Spacer(); Image(systemName: entry.submissions.contains(student.id) ? "checkmark.circle.fill" : "circle").font(.system(size: 22, weight: .ultraLight)).foregroundStyle(Color.sage) }.foregroundStyle(Color.ink) } }
            } }
        }
    }
    func assessmentContent(_ entry: Entry) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            related("Test results", items: store.items(.grade).filter { $0.assessmentID == id })
            Button("Record a result", systemImage: "plus") { create = .grade }.buttonStyle(GoldButton())
        }
    }
    func actions(_ entry: Entry) -> some View {
        VStack(spacing: 17) {
            if [.lesson, .task, .reminder, .homework, .assessment].contains(entry.kind) { Button { withAnimation { _ = store.toggle(entry) } } label: { Label(entry.completed ? "Reopen" : "Mark completed", systemImage: entry.completed ? "arrow.uturn.backward" : "checkmark") }.buttonStyle(GoldButton()) }
            if entry.kind == .template { Button("Plan a lesson from this template", systemImage: "plus") { var lesson = entry; lesson.id = UUID(); lesson.kind = .lesson; lesson.date = Entry.suggestedDate(for: .lesson); lesson.createdAt = Date(); lesson.archived = false; lesson.completed = false; draftLesson = lesson }.font(.subheadline) }
            if entry.kind == .lesson { Button("Save as a lesson template", systemImage: "doc.on.doc") { var template = Entry(kind: .template, title: entry.title); template.objectives = entry.objectives; template.activities = entry.activities; template.duration = entry.duration; if store.save(template) { store.notice = "Saved to Lesson Templates." } }.font(.subheadline) }
            Button(entry.archived ? "Restore from archive" : "Move to archive", systemImage: entry.archived ? "arrow.uturn.backward" : "archivebox") { store.archive(entry) }.font(.subheadline)
            Button("Delete permanently", role: .destructive) { deleting = true }.font(.caption)
        }.frame(maxWidth: .infinity).padding(.top, 14)
    }
}
