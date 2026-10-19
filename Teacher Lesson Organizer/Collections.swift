import SwiftUI
import Charts

struct CollectionPage: View {
    @EnvironmentObject var store: OrganizerStore
    var screen: Screen
    var kind: EntryKind
    var classID: UUID? = nil
    var studentID: UUID? = nil
    @State private var query = ""
    @State private var filterClass: UUID?
    @State private var filter = "All"
    @State private var sort = "Recent"
    @State private var initializedSort = false
    @State private var editing = false
    @State private var filters = false
    var entries: [Entry] {
        var items = store.items(kind).filter {
            (classID == nil || $0.classID == classID) && (studentID == nil || $0.studentID == studentID)
            && (filterClass == nil || $0.classID == filterClass) && (query.isEmpty || ($0.title + " " + $0.detail).localizedCaseInsensitiveContains(query))
        }
        if filter == "Open" { items = items.filter { !$0.completed } }
        if filter == "Completed" { items = items.filter { $0.completed } }
        if screen == .attachments { items = items.filter { $0.fileName != nil } }
        if screen == .upcoming { items = items.filter { $0.date >= Date() && !$0.completed } }
        return items.sorted {
            if sort == "A–Z" { return $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            if sort == "Date" { return $0.date < $1.date }
            return $0.createdAt > $1.createdAt
        }
    }
    var body: some View {
        Page {
            HStack(alignment: .top) {
                EditorialTitle(eyebrow: eyebrow, title: heading, subtitle: subtitle)
                Button { editing = true } label: { RoundIcon(icon: "plus", dark: true).background(Color.ink, in: Circle()) }.accessibilityLabel("Add \(kind.singular)").padding(.top, 27)
            }
            if kind == .classroom { classSummary }
            searchBar
            HStack {
                Kicker(text: "\(entries.count) \(kind == .classroom ? "class portfolios" : "records")", color: .secondaryInk)
                Spacer()
                if kind.needsClass || hasStatus { Button { filters = true } label: { HStack(spacing: 5) { Image(systemName: "line.3.horizontal.decrease"); Text(filterClass == nil ? "Filter" : "Filtered") }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.ink) } }
                Menu { Picker("Sort", selection: $sort) { Text("Recent").tag("Recent"); Text("A–Z").tag("A–Z"); Text("Date").tag("Date") } } label: { Image(systemName: "arrow.up.arrow.down").font(.system(size: 11)).foregroundStyle(Color.gold).padding(.leading, 12) }.accessibilityLabel("Sort entries")
            }
            if [.lesson, .homework, .task, .reminder, .assessment].contains(kind) { PremiumSegment(options: ["All", "Open", "Completed"], selection: $filter) }
            if entries.isEmpty && (!query.isEmpty || filterClass != nil || filter != "All") {
                EmptyCard(icon: "line.3.horizontal.decrease", title: "No matching records.", message: "Change your search or reset the filters to see more of your collection.")
                Button("Clear search & filters") { query = ""; filterClass = nil; filter = "All" }.buttonStyle(GoldButton())
            } else if entries.isEmpty {
                EmptyCard(icon: kind.icon, title: query.isEmpty ? "The beginning of something good." : "No matches", message: query.isEmpty ? "Add a \(kind.singular.lowercased()) to your personal teaching collection." : "Try a different search or adjust your filters.")
                Button("Add \(kind.singular.lowercased())", systemImage: "plus") { editing = true }.buttonStyle(GoldButton())
            } else if kind == .student {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 14)], spacing: 14) { ForEach(entries) { entry in NavigationLink(value: entry) { StudentCollectionCard(student: entry) }.buttonStyle(QuietPress()) } }
            } else {
                VStack(spacing: kind == .lesson ? 0 : 18) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink(value: entry) {
                            if kind == .classroom { ClassPortfolioCard(entry: entry, index: index + 1) }
                            else if kind == .lesson { VStack(alignment: .leading, spacing: 11) { if index == 0 || !Calendar.current.isDate(entries[index - 1].date, inSameDayAs: entry.date) { Kicker(text: entry.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).padding(.bottom, 3).padding(.top, index == 0 ? 0 : 16) }; AgendaLessonCard(lesson: entry, index: index + 1, last: index == entries.count - 1) } }
                            else if kind == .homework { HomeworkCollectionCard(entry: entry) }
                            else if [.grade, .category].contains(kind) { PaperCard { EntryRow(entry: entry) } }
                            else { ResourceCollectionCard(entry: entry, index: index + 1) }
                        }.buttonStyle(QuietPress()).contextMenu { Button("Archive", systemImage: "archivebox") { store.archive(entry) } }
                    }
                }
            }
        }.navigationTitle(screen.rawValue).navigationBarTitleDisplayMode(.inline)
            .onAppear { if !initializedSort { sort = kind == .lesson ? "Date" : "Recent"; initializedSort = true } }
            .sheet(isPresented: $editing) { EntryEditor(kind: kind, classID: classID, studentID: studentID, requiresAttachment: screen == .attachments) }
            .sheet(isPresented: $filters) { FilterSheet(selectedClass: $filterClass, status: $filter, showStatus: hasStatus, showClass: kind.needsClass) }
    }
    var hasStatus: Bool { [.lesson, .homework, .task, .reminder, .assessment].contains(kind) }
    var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .light)).foregroundStyle(Color.gold)
            TextField("Find in \(screen.rawValue.lowercased())", text: $query).font(.system(size: 12)).foregroundStyle(Color.ink)
            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.secondaryInk).font(.system(size: 13)) }.accessibilityLabel("Clear search") }
        }.padding(.horizontal, 17).padding(.vertical, 16).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 15)).overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.fineLine.opacity(0.6), lineWidth: 0.7))
    }
    var classSummary: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) { Text("\(store.items(.student).count)").font(.system(size: 30, design: .serif)).foregroundStyle(Color.ink); Kicker(text: "Students", color: .secondaryInk) }.frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(Color.fineLine).frame(width: 0.5, height: 35).padding(.trailing, 25)
            VStack(alignment: .leading, spacing: 5) { Text(store.average().map { "\(Int($0))%" } ?? "—").font(.system(size: 30, design: .serif)).foregroundStyle(Color.ink); Kicker(text: "Overall average", color: .secondaryInk) }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding(.vertical, 3)
    }
    var heading: String { switch kind { case .classroom: "Your class collection."; case .student: "Every individual."; case .homework: "Work, in progress."; case .lesson: "The lesson journal."; case .material: "The resource library."; default: screen.rawValue + "." } }
    var eyebrow: String { switch kind { case .classroom: "People. Potential. Progress."; case .student: "The student directory"; case .homework: "Beyond the classroom"; default: "Your personal collection" } }
    var subtitle: String {
        switch kind {
        case .classroom: "A considered space for every class you guide."
        case .student: "The people at the heart of your teaching."
        case .lesson: "Plans, ideas and the moments between."
        case .homework: "Assignments, deadlines and individual submissions."
        case .template: "Your most useful teaching sequences, ready to revisit."
        case .material: "Reading, references and resources worth keeping."
        default: "The details behind a well-considered teaching day."
        }
    }
}
struct ClassPortfolioCard: View {
    @EnvironmentObject var store: OrganizerStore
    var entry: Entry
    var index: Int = 1
    var students: [Entry] { store.items(.student).filter { $0.classID == entry.id } }
    var grades: [Entry] { store.items(.grade).filter { $0.classID == entry.id }.sorted { $0.date < $1.date } }
    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack { Kicker(text: String(format: "Class portfolio / %02d", index), color: .champagne); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 13)).foregroundStyle(Color.champagne) }
            VStack(alignment: .leading, spacing: 8) { Text(entry.title).font(.system(size: 32, design: .serif)).tracking(-0.9).foregroundStyle(Color.paper); Text(entry.room.isEmpty ? "Personal teaching portfolio" : entry.room).font(.system(size: 10)).foregroundStyle(Color.paper.opacity(0.5)) }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 6) { Text(store.average(classID: entry.id).map { "\(Int($0))%" } ?? "—").font(.system(size: 35, design: .serif)).tracking(-1).foregroundStyle(Color.paper); Kicker(text: "Weighted average", color: .paper.opacity(0.4)) }
                Spacer()
                if grades.count > 1 {
                    Chart(Array(grades.enumerated()), id: \.element.id) { index, grade in
                        AreaMark(x: .value("Record", index), yStart: .value("Base", 0), yEnd: .value("Score", grade.percentage)).foregroundStyle(LinearGradient(colors: [.champagne.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                        LineMark(x: .value("Record", index), y: .value("Score", grade.percentage)).foregroundStyle(Color.champagne).lineStyle(StrokeStyle(lineWidth: 1.4)).interpolationMethod(.monotone)
                    }.chartYScale(domain: 0...100).chartXAxis(.hidden).chartYAxis(.hidden).frame(width: 112, height: 48).accessibilityLabel("Recent grades for \(entry.title)")
                } else { Image(systemName: "rectangle.3.group").font(.system(size: 45, weight: .ultraLight)).foregroundStyle(Color.champagne.opacity(0.3)) }
            }
            Rectangle().fill(.white.opacity(0.1)).frame(height: 0.6)
            HStack {
                HStack(spacing: -9) { ForEach(students.prefix(4)) { student in Avatar(name: student.title, size: 29, dark: true).overlay(Circle().stroke(Color.ink, lineWidth: 2)) } }
                Text("\(students.count) students").font(.system(size: 10)).foregroundStyle(Color.paper.opacity(0.55)).padding(.leading, students.isEmpty ? 0 : 3)
                Spacer()
                Text("\(store.items(.lesson).filter { $0.classID == entry.id }.count) LESSONS").font(.system(size: 7, weight: .medium)).tracking(1).foregroundStyle(Color.champagne.opacity(0.75))
            }
        }.padding(24).navySurface()
    }
}
struct StudentCollectionCard: View {
    @EnvironmentObject var store: OrganizerStore
    var student: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack { Avatar(name: student.title, size: 44); Spacer(minLength: 0); Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Color.gold) }
            VStack(alignment: .leading, spacing: 6) { Text(student.title).font(.system(size: 20, design: .serif)).foregroundStyle(Color.ink).lineLimit(2).frame(minHeight: 46, alignment: .top); Text(store.name(student.classID)).font(.system(size: 9)).foregroundStyle(Color.secondaryInk).lineLimit(1) }
            Rectangle().fill(Color.fineLine.opacity(0.5)).frame(height: 0.5)
            HStack(alignment: .firstTextBaseline) { Text(store.average(studentID: student.id).map { "\(Int($0))%" } ?? "—").font(.system(size: 25, design: .serif)).foregroundStyle(Color.ink); Spacer(); Text("AVERAGE").font(.system(size: 6, weight: .medium)).tracking(1).foregroundStyle(Color.gold) }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading).background(.white, in: RoundedRectangle(cornerRadius: 23)).overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.fineLine.opacity(0.25), lineWidth: 0.7))
    }
}
struct HomeworkCollectionCard: View {
    @EnvironmentObject var store: OrganizerStore
    var entry: Entry
    var students: [Entry] { store.items(.student).filter { $0.classID == entry.classID } }
    var received: Int { entry.submissions.filter { id in students.contains { $0.id == id } }.count }
    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 19) {
                HStack { Kicker(text: store.name(entry.classID)); Spacer(); StatusPill(text: entry.completed ? "Complete" : entry.date < Date() ? "Overdue" : "Assigned", color: entry.completed ? .sage : .gold) }
                Text(entry.title).font(.system(size: 27, design: .serif)).tracking(-0.6).foregroundStyle(Color.ink)
                if !entry.detail.isEmpty { Text(entry.detail).font(.system(size: 11)).foregroundStyle(Color.secondaryInk).lineSpacing(4).lineLimit(2) }
                Rectangle().fill(Color.fineLine.opacity(0.6)).frame(height: 0.5)
                HStack(spacing: 12) {
                    ProgressRing(value: Double(received) / Double(max(students.count, 1)), size: 33, line: 2.5)
                    VStack(alignment: .leading, spacing: 4) { Text("\(received) / \(students.count) received").font(.system(size: 11, weight: .medium)).foregroundStyle(Color.ink); Text("SUBMISSION TRACKER").font(.system(size: 6, weight: .medium)).tracking(1.2).foregroundStyle(Color.secondaryInk) }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) { Text(entry.date.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 15, design: .serif)).foregroundStyle(Color.ink); Text("DUE DATE").font(.system(size: 6, weight: .medium)).tracking(1.2).foregroundStyle(Color.gold) }
                }
            }
        }
    }
}
struct ResourceCollectionCard: View {
    @EnvironmentObject var store: OrganizerStore
    var entry: Entry
    var index: Int
    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 17) {
                HStack { Image(systemName: entry.kind.icon).font(.system(size: 22, weight: .light)).foregroundStyle(Color.gold); Spacer(); Kicker(text: entry.kind == .material ? (entry.originalFileName.map { URL(fileURLWithPath: $0).pathExtension.uppercased() } ?? "Reference") : String(format: "Entry %02d", index), color: .secondaryInk) }
                Text(entry.title).font(.system(size: 24, design: .serif)).tracking(-0.5).foregroundStyle(Color.ink).lineLimit(2)
                if !entry.detail.isEmpty { Text(entry.detail).font(.system(size: 12)).foregroundStyle(Color.secondaryInk).lineSpacing(5).lineLimit(3) }
                HStack {
                    if let student = store.entry(entry.studentID) { HStack(spacing: 6) { Avatar(name: student.title, size: 23); Text(student.title).font(.system(size: 9)).foregroundStyle(Color.secondaryInk) } }
                    else if entry.kind.hasDate { Text(entry.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(Color.secondaryInk) }
                    else { Text(store.entry(entry.subjectID)?.title ?? entry.kind.singular).font(.system(size: 10)).foregroundStyle(Color.secondaryInk) }
                    Spacer(); Image(systemName: entry.completed ? "checkmark.circle.fill" : "arrow.up.right").font(.system(size: 12)).foregroundStyle(entry.completed ? Color.sage : .gold)
                }
            }
        }
    }
}
struct FilterSheet: View {
    @EnvironmentObject var store: OrganizerStore
    @Environment(\.dismiss) var dismiss
    @Binding var selectedClass: UUID?
    @Binding var status: String
    var showStatus: Bool
    var showClass: Bool
    var body: some View {
        NavigationStack {
            Form {
                if showClass { Section("Class") { Picker("Class", selection: $selectedClass) { Text("All classes").tag(nil as UUID?); ForEach(store.items(.classroom)) { Text($0.title).tag(Optional($0.id)) } }.pickerStyle(.inline).labelsHidden() } }
                if showStatus { Section("Status") { Picker("Status", selection: $status) { ForEach(["All", "Open", "Completed"], id: \.self) { Text($0) } }.pickerStyle(.segmented) } }
                Button("Reset filters") { selectedClass = nil; status = "All" }
            }.contentMargins(.bottom, 32, for: .scrollContent).scrollContentBackground(.hidden).background(Color.paper).navigationTitle("Filters").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Apply") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}
