import SwiftUI
import UniformTypeIdentifiers

struct EntryEditor: View {
    @EnvironmentObject var store: OrganizerStore
    @Environment(\.dismiss) var dismiss
    @State private var draft: Entry
    @State private var importing = false
    @State private var formError: String?
    @State private var relatedKind: EntryKind?
    @State private var confirmingDiscard = false
    @State private var prepared = false
    @State private var scoreInput = ""
    @State private var maximumInput = ""
    @State private var baseline: Entry
    let isNew: Bool
    let requiresAssessment: Bool
    let requiresAttachment: Bool
    let onSave: ((Entry) -> Void)?
    init(kind: EntryKind, entry: Entry? = nil, classID: UUID? = nil, studentID: UUID? = nil, assessmentID: UUID? = nil, creating: Bool = false, requiresAssessment: Bool = false, requiresAttachment: Bool = false, onSave: ((Entry) -> Void)? = nil) {
        isNew = entry == nil || creating
        self.requiresAssessment = requiresAssessment
        self.requiresAttachment = requiresAttachment
        self.onSave = onSave
        let initial = entry ?? Entry(kind: kind, title: "", classID: classID, studentID: studentID, assessmentID: assessmentID, date: Entry.suggestedDate(for: kind))
        _draft = State(initialValue: initial)
        _baseline = State(initialValue: initial)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 17) {
                        HStack { Kicker(text: "Personal workspace", color: .champagne); Spacer(); Image(systemName: draft.kind.icon).font(.system(size: 24, weight: .ultraLight)).foregroundStyle(Color.champagne) }
                        Text(editorHeading).font(.system(size: 30, design: .serif)).tracking(-0.7).foregroundStyle(Color.paper)
                        Text(isNew ? "A new addition to your teaching collection." : "Refine the details of this record.").font(.system(size: 10)).foregroundStyle(Color.paper.opacity(0.5))
                    }.padding(23).frame(maxWidth: .infinity, alignment: .leading).navySurface(radius: 23)
                }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                Section {
                    TextField(draft.kind == .student ? "Full name" : "Title", text: $draft.title).font(.system(size: 21, design: .serif))
                    TextField(draft.kind == .student ? "Learning preferences, context…" : "Details, instructions or reflections…", text: $draft.detail, axis: .vertical).lineLimit(4...8)
                } header: { Text("The essentials") }
                if draft.kind.needsClass {
                    Section("Connections") {
                        Picker("Class", selection: $draft.classID) { Text("Choose a class").tag(nil as UUID?); ForEach(store.choices(.classroom, including: draft.classID)) { Text($0.title).tag(Optional($0.id)) } }
                            .onChange(of: draft.classID) { _, new in
                                if let student = store.entry(draft.studentID), student.classID != new { draft.studentID = nil }
                                if let assessment = store.entry(draft.assessmentID), assessment.classID != new { draft.assessmentID = nil }
                            }
                        Button("Add a class", systemImage: "plus.circle") { relatedKind = .classroom }.font(.caption)
                        if draft.kind.needsStudent {
                            Picker("Student", selection: $draft.studentID) { Text("Choose a student").tag(nil as UUID?); ForEach(store.choices(.student, including: draft.studentID).filter { draft.classID == nil || $0.classID == draft.classID || $0.id == draft.studentID }) { Text($0.title).tag(Optional($0.id)) } }
                                .onChange(of: draft.studentID) { _, id in if let student = store.entry(id) { draft.classID = student.classID } }
                        }
                        if draft.kind.needsStudent { Button("Add a student", systemImage: "person.badge.plus") { relatedKind = .student }.font(.caption) }
                        if [.lesson, .homework, .assessment].contains(draft.kind) { subjectPicker; Button("Add a subject", systemImage: "plus.circle") { relatedKind = .subject }.font(.caption) }
                    }
                }
                if draft.kind == .material { Section("Subject") { subjectPicker; Button("Add a subject", systemImage: "plus.circle") { relatedKind = .subject }.font(.caption) } }
                if draft.kind.hasDate {
                    Section(draft.kind == .homework || draft.kind == .task ? "Deadline" : "When") {
                        DatePicker("Date", selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                        if draft.kind == .lesson { Stepper("Duration: \(draft.duration) min", value: $draft.duration, in: 5...360, step: 5) }
                    }
                }
                if [.lesson, .template].contains(draft.kind) {
                    Section("Lesson plan") {
                        if draft.kind == .lesson && !store.items(.template).isEmpty {
                            Menu("Use a saved template") { ForEach(store.items(.template)) { template in Button(template.title) { draft.objectives = template.objectives; draft.activities = template.activities; draft.duration = template.duration; if draft.title.isEmpty { draft.title = template.title } } } }
                        }
                        TextField("Learning objectives", text: $draft.objectives, axis: .vertical).lineLimit(3...7)
                        TextField("Activities & timing", text: $draft.activities, axis: .vertical).lineLimit(4...10)
                        if draft.kind == .lesson { Picker("Preparation", selection: $draft.status) { Text("Planned").tag("Planned"); Text("Ready to teach").tag("Ready to teach"); Text("Needs preparation").tag("Needs preparation") } }
                    }
                }
                if [.classroom, .lesson].contains(draft.kind) { Section("Location") { TextField("Room or location", text: $draft.room) } }
                if draft.kind == .grade {
                    Section {
                        HStack { Text("Points earned"); Spacer(); TextField("Score", text: $scoreInput).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        HStack { Text("Out of"); Spacer(); TextField("Maximum", text: $maximumInput).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                        Picker("Category", selection: $draft.categoryID) { Text("Uncategorized (×1)").tag(nil as UUID?); ForEach(store.choices(.category, including: draft.categoryID)) { Text("\($0.title) (×\($0.weight.formatted()))").tag(Optional($0.id)) } }
                        Button("Add a grade category", systemImage: "plus.circle") { relatedKind = .category }.font(.caption)
                        Picker("Test / quiz", selection: $draft.assessmentID) { Text(requiresAssessment ? "Choose a test or quiz" : "None").tag(nil as UUID?); ForEach(store.choices(.assessment, including: draft.assessmentID).filter { $0.classID == draft.classID }) { Text($0.title).tag(Optional($0.id)) } }
                        .onChange(of: draft.assessmentID) { _, id in if let assessment = store.entry(id) { draft.maximum = assessment.maximum; maximumInput = numberText(assessment.maximum); if draft.title.isEmpty { draft.title = assessment.title } } }
                        Button("Add a test or quiz", systemImage: "plus.circle") { relatedKind = .assessment }.font(.caption)
                    } header: { Text("Score") } footer: { Text("Averages use each category's weight. An uncategorized grade has weight 1.") }
                }
                if draft.kind == .assessment { Section("Scoring") { HStack { Text("Maximum points"); Spacer(); TextField("Maximum", text: $maximumInput).keyboardType(.decimalPad).multilineTextAlignment(.trailing) } } }
                if draft.kind == .category { Section { Stepper("Weight: ×\(draft.weight.formatted())", value: $draft.weight, in: 0.5...10, step: 0.5) } footer: { Text("A weight of 2 gives each grade in this category twice the influence of a weight of 1.") } }
                if draft.kind == .behavior { Section("Observation") { Picker("Type", selection: $draft.status) { Text("Positive").tag("Positive"); Text("Follow-up").tag("Follow-up"); Text("Observation").tag("Observation") } } }
                if draft.kind == .material {
                    Section("Local attachment") {
                        Button { importing = true } label: { Label(draft.originalFileName ?? "Attach a file", systemImage: "paperclip") }
                        if draft.fileName != nil { Button("Remove attachment", role: .destructive) { store.discardUnreferencedFile(draft.fileName); draft.fileName = nil; draft.originalFileName = nil } }
                        Text("Files up to 25 MB are copied into this app and remain available offline.").font(.caption).foregroundStyle(Color.secondaryInk)
                    }
                }
                if draft.kind == .reminder { Section { Text("An on-device notification is scheduled when you save a future reminder. Notification permission is requested only when needed.").font(.caption).foregroundStyle(Color.secondaryInk) } }
                if [.task, .homework, .lesson, .assessment, .reminder].contains(draft.kind) { Section { Toggle("Completed", isOn: $draft.completed).tint(.sage) } }
            }.font(.system(size: 13)).listSectionSpacing(24).environment(\.defaultMinListRowHeight, 53).scrollContentBackground(.hidden).background(Color.paper)
                .contentMargins(.bottom, 32, for: .scrollContent)
                .scrollDismissesKeyboard(.interactively)
                .navigationTitle("\(isNew ? "Add" : "Edit") \(draft.kind.singular.lowercased())").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { if hasChanges { confirmingDiscard = true } else { dismiss() } } }
                    ToolbarItem(placement: .confirmationAction) { Button { save() } label: { Text("Save").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.champagne).padding(.horizontal, 17).padding(.vertical, 9).background(Color.ink, in: Capsule()) }.disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                    ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
                }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                    switch result {
                    case .success(let url): do { let old = draft.fileName; try store.importFile(url, for: &draft); store.discardUnreferencedFile(old) } catch { formError = error.localizedDescription }
                    case .failure(let error): formError = error.localizedDescription
                    }
                }
                .alert("Check this record", isPresented: Binding(get: { formError != nil }, set: { if !$0 { formError = nil } })) { Button("OK") { formError = nil } } message: { Text(formError ?? "") }
                .interactiveDismissDisabled(hasChanges)
                .confirmationDialog("Discard your unsaved changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) { Button("Discard changes", role: .destructive) { dismiss() }; Button("Keep editing", role: .cancel) { } }
                .sheet(item: $relatedKind) { kind in
                    EntryEditor(kind: kind, classID: draft.classID) { saved in
                        switch saved.kind {
                        case .classroom: draft.classID = saved.id
                        case .student: draft.classID = saved.classID; draft.studentID = saved.id
                        case .subject: draft.subjectID = saved.id
                        case .category: draft.categoryID = saved.id
                        case .assessment: draft.classID = saved.classID; draft.assessmentID = saved.id; draft.maximum = saved.maximum; maximumInput = numberText(saved.maximum)
                        default: break
                        }
                    }
                }
                .onAppear { prepare() }
                .onDisappear { if relatedKind == nil { store.discardUnreferencedFile(draft.fileName) } }
        }
    }
    var editorHeading: String {
        if !isNew { return "The details, considered." }
        return switch draft.kind {
        case .lesson: "Shape the next lesson."
        case .student: "A new individual."
        case .classroom: "A place to grow."
        case .homework: "Learning beyond the lesson."
        case .grade: "A moment of progress."
        case .note, .behavior: "Worth remembering."
        case .material: "Add to your library."
        default: "Make it your own."
        }
    }
    var subjectPicker: some View { Picker("Subject", selection: $draft.subjectID) { Text("Not assigned").tag(nil as UUID?); ForEach(store.choices(.subject, including: draft.subjectID)) { Text($0.title).tag(Optional($0.id)) } } }
    var hasChanges: Bool { draft != baseline || (prepared && draft.kind == .grade && scoreInput != numberText(baseline.score)) || (prepared && [.grade, .assessment].contains(draft.kind) && maximumInput != numberText(baseline.maximum)) }
    func numberText(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0...8)).grouping(.never).locale(Locale(identifier: "en_US"))) }
    func prepare() {
        guard !prepared else { return }; prepared = true
        if isNew {
            if draft.kind == .behavior { draft.status = "Positive" }
            if let assessment = store.entry(draft.assessmentID) { draft.classID = assessment.classID; draft.maximum = assessment.maximum; maximumInput = numberText(assessment.maximum); if draft.title.isEmpty { draft.title = assessment.title } }
            if draft.classID == nil && store.items(.classroom).count == 1 { draft.classID = store.items(.classroom).first?.id }
        }
        scoreInput = numberText(draft.score); maximumInput = numberText(draft.maximum)
        baseline = draft
    }
    func save() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if draft.title.isEmpty { formError = "Enter a title or name."; return }
        if draft.kind.needsClass && draft.classID == nil { formError = "Choose a class or add one in Connections."; return }
        if draft.kind.needsStudent && draft.studentID == nil { formError = "Choose a student for this record."; return }
        if requiresAttachment && draft.fileName == nil { formError = "Choose a file to add it to Attachments."; return }
        if requiresAssessment && draft.assessmentID == nil { formError = "Choose or add a test or quiz for this result."; return }
        if [.grade, .assessment].contains(draft.kind) {
            guard let maximum = Double(maximumInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) else { formError = "Enter a valid maximum score."; return }
            draft.maximum = maximum
            if draft.kind == .grade { guard let score = Double(scoreInput.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")) else { formError = "Enter a valid score."; return }; draft.score = score }
        }
        if [.grade, .assessment].contains(draft.kind) && (!draft.score.isFinite || !draft.maximum.isFinite || draft.maximum <= 0 || draft.score < 0 || draft.score > draft.maximum) { formError = "Enter a score between zero and the maximum. The maximum must be greater than zero."; return }
        if draft.kind == .reminder && !draft.completed && draft.date <= Date() && (isNew || draft.date != baseline.date) { formError = "Choose a future time for your reminder."; return }
        if store.save(draft) { onSave?(store.entry(draft.id) ?? draft); dismiss() }
        else { formError = store.error ?? "This record could not be saved."; store.error = nil }
    }
}
