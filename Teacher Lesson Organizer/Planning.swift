import SwiftUI

struct CalendarPage: View {
    @EnvironmentObject var store: OrganizerStore
    var scheduleOnly = false
    @State private var selected = Date()
    @State private var create: EntryKind?
    var events: [Entry] { store.workspace.entries.filter { !$0.archived && [.lesson, .homework, .assessment, .reminder, .task].contains($0.kind) && Calendar.current.isDate($0.date, inSameDayAs: selected) && (!scheduleOnly || $0.kind == .lesson) }.sorted { $0.date < $1.date } }
    var body: some View {
        Page {
            HStack(alignment: .top) {
                EditorialTitle(eyebrow: "Time, thoughtfully arranged", title: scheduleOnly ? "The weekly edit." : "A considered calendar.", subtitle: "Lessons, deadlines and a little room to think.")
                Menu { Button("Plan a lesson") { create = .lesson }; Button("Add task") { create = .task }; Button("Set reminder") { create = .reminder } } label: { RoundIcon(icon: "plus", dark: true).background(Color.ink, in: Circle()) }.accessibilityLabel("Add to planner").padding(.top, 27)
            }
            if scheduleOnly { weekStrip } else { MonthCalendar(selected: $selected, eventDates: store.workspace.entries.filter { !$0.archived && $0.kind.hasDate && ![.grade, .note, .behavior].contains($0.kind) }.map(\.date)) }
            daySummary
            HStack { SectionLabel(title: selected.formatted(.dateTime.weekday(.wide)), caption: selected.formatted(.dateTime.day().month(.wide))); Spacer(minLength: 0) }
            if events.isEmpty { EmptyCard(icon: "calendar.badge.plus", title: "An open page.", message: "Nothing scheduled for this day. Add a lesson, a task or a reminder when you are ready.") }
            ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                NavigationLink(value: event) {
                    if event.kind == .lesson { AgendaLessonCard(lesson: event, index: index + 1, last: index == events.count - 1) }
                    else { HStack(alignment: .top, spacing: 14) { Text(event.date.formatted(.dateTime.hour().minute())).font(.system(size: 11)).foregroundStyle(Color.secondaryInk).frame(width: 52, alignment: .trailing).padding(.top, 22); PaperCard { VStack(alignment: .leading, spacing: 12) { HStack { Kicker(text: event.kind.singular); Spacer(); Image(systemName: event.kind.icon).font(.system(size: 13, weight: .light)).foregroundStyle(Color.gold) }; Text(event.title).font(.system(size: 22, design: .serif)).foregroundStyle(Color.ink); StatusPill(text: event.completed ? "Completed" : "Scheduled", color: event.completed ? .sage : .gold) } } } }
                }.buttonStyle(QuietPress())
            }
            Button("Plan a lesson", systemImage: "plus") { create = .lesson }.buttonStyle(GoldButton())
            HStack { NavigationLink(value: Screen.upcoming) { Label("Upcoming lessons", systemImage: "book") }; Spacer(); NavigationLink(value: Screen.deadlines) { Label("Deadlines", systemImage: "clock") } }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.gold)
        }.navigationTitle(scheduleOnly ? "Schedule" : "Planner").navigationBarTitleDisplayMode(.inline)
            .sheet(item: $create) { kind in EntryEditor(kind: kind, entry: Entry(kind: kind, title: "", date: Entry.suggestedDate(for: kind, on: selected)), creating: true) }
    }
    var daySummary: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 6) { Text("\(events.filter { $0.kind == .lesson }.count)").font(.system(size: 33, design: .serif)).foregroundStyle(Color.paper); Kicker(text: "Lessons", color: .paper.opacity(0.4)) }.frame(maxWidth: .infinity, alignment: .leading)
            Rectangle().fill(.white.opacity(0.12)).frame(width: 0.5, height: 38)
            VStack(alignment: .leading, spacing: 6) { Text("\(events.filter { $0.kind == .lesson }.reduce(0) { $0 + $1.duration })").font(.system(size: 33, design: .serif)).foregroundStyle(Color.paper); Kicker(text: "Teaching minutes", color: .paper.opacity(0.4)) }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "sun.horizon").font(.system(size: 28, weight: .ultraLight)).foregroundStyle(Color.champagne.opacity(0.65))
        }.padding(23).navySurface(radius: 23)
    }
    var weekStrip: some View {
        PaperCard {
            VStack(spacing: 20) {
                HStack { Button { shift(-7) } label: { Image(systemName: "chevron.left").font(.system(size: 12)) }.accessibilityLabel("Previous week"); Spacer(); Text(selected.formatted(.dateTime.month(.wide).year())).font(.system(size: 23, design: .serif)).foregroundStyle(Color.ink); Spacer(); Button { shift(7) } label: { Image(systemName: "chevron.right").font(.system(size: 12)) }.accessibilityLabel("Next week") }
                HStack(spacing: 4) { ForEach(weekDays, id: \.self) { date in
                    let active = Calendar.current.isDate(date, inSameDayAs: selected)
                    Button { withAnimation(.spring(response: 0.3)) { selected = date } } label: {
                        VStack(spacing: 11) { Text(date.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)); Text(date.formatted(.dateTime.day())).font(.system(size: 24, design: .serif)); Circle().fill(store.items(.lesson).contains { Calendar.current.isDate($0.date, inSameDayAs: date) } ? Color.gold : .clear).frame(width: 3, height: 3) }.foregroundStyle(active ? Color.paper : .ink).frame(maxWidth: .infinity).padding(.vertical, 14).background(active ? Color.ink : .clear, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                } }
                Button("Return to today") { withAnimation { selected = Date() } }.font(.system(size: 9, weight: .medium)).foregroundStyle(Color.gold)
            }
        }
    }
    var weekDays: [Date] { let start = Calendar.current.dateInterval(of: .weekOfYear, for: selected)?.start ?? selected; return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) } }
    func shift(_ days: Int) { withAnimation { selected = Calendar.current.date(byAdding: .day, value: days, to: selected) ?? selected } }
}
struct MonthCalendar: View {
    @Binding var selected: Date
    var eventDates: [Date]
    @State private var month = Date()
    var calendar: Calendar { var value = Calendar.current; value.locale = Locale(identifier: "en_US"); return value }
    var dates: [Date?] {
        guard let start = calendar.dateInterval(of: .month, for: month)?.start, let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let offset = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: offset) + range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: start) }.map(Optional.some)
    }
    var weekdays: [String] { let symbols = calendar.veryShortStandaloneWeekdaySymbols; let offset = calendar.firstWeekday - 1; return Array(symbols[offset...] + symbols[..<offset]) }
    var body: some View {
        PaperCard {
            VStack(spacing: 22) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 5) { Kicker(text: month.formatted(.dateTime.year())); Text(month.formatted(.dateTime.month(.wide))).font(.system(size: 29, design: .serif)).tracking(-0.7).foregroundStyle(Color.ink) }
                    Spacer()
                    Button { changeMonth(-1) } label: { Image(systemName: "chevron.left").font(.system(size: 11)).frame(width: 30, height: 30).background(Color.paper, in: Circle()) }.accessibilityLabel("Previous month")
                    Button { changeMonth(1) } label: { Image(systemName: "chevron.right").font(.system(size: 11)).frame(width: 30, height: 30).background(Color.paper, in: Circle()) }.accessibilityLabel("Next month")
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7), spacing: 9) {
                    ForEach(Array(weekdays.enumerated()), id: \.offset) { _, text in Text(text).font(.system(size: 8, weight: .medium)).foregroundStyle(Color.secondaryInk).frame(maxWidth: .infinity).padding(.bottom, 7) }
                    ForEach(Array(dates.enumerated()), id: \.offset) { _, date in
                        if let date {
                            let active = calendar.isDate(date, inSameDayAs: selected)
                            Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selected = date } } label: {
                                VStack(spacing: 4) { Text(date.formatted(.dateTime.day())).font(.system(size: 13, weight: active ? .semibold : .regular)); Circle().fill(eventDates.contains { calendar.isDate($0, inSameDayAs: date) } ? (active ? Color.champagne : .gold) : .clear).frame(width: 3, height: 3) }.frame(maxWidth: .infinity).frame(height: 39).foregroundStyle(active ? Color.paper : .ink).background(active ? Color.ink : .clear, in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(calendar.isDateInToday(date) && !active ? Color.gold.opacity(0.5) : .clear, lineWidth: 0.8))
                            }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted)).accessibilityAddTraits(active ? .isSelected : [])
                        } else { Color.clear.frame(height: 39).accessibilityHidden(true) }
                    }
                }
                HStack(spacing: 5) { Circle().fill(Color.gold).frame(width: 4, height: 4); Text("A planned moment").font(.system(size: 9)).foregroundStyle(Color.secondaryInk); Spacer(); Button("Today") { withAnimation { selected = Date(); month = Date() } }.font(.system(size: 10, weight: .medium)).foregroundStyle(Color.gold) }
            }
        }.onAppear { month = selected }.onChange(of: selected) { _, date in if !calendar.isDate(date, equalTo: month, toGranularity: .month) { month = date } }
    }
    func changeMonth(_ value: Int) { guard let next = calendar.date(byAdding: .month, value: value, to: month), let start = calendar.dateInterval(of: .month, for: next)?.start else { return }; withAnimation(.easeInOut(duration: 0.2)) { month = start; selected = start } }
}
struct AttendancePage: View {
    @EnvironmentObject var store: OrganizerStore
    @State private var classID: UUID?
    @State private var date: Date
    init(initialClassID: UUID? = nil, initialDate: Date = Date()) { _classID = State(initialValue: initialClassID); _date = State(initialValue: initialDate) }
    var students: [Entry] { store.items(.student).filter { $0.classID == classID && classID != nil }.sorted { $0.title < $1.title } }
    var marked: Int { students.filter { store.attendance($0.id, on: date) != nil }.count }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "Every presence matters", title: "The daily register.", subtitle: "A clear record of the people in the room.")
            PaperCard {
                VStack(spacing: 14) {
                    Picker("Class", selection: $classID) { Text("Choose class").tag(nil as UUID?); ForEach(store.choices(.classroom, including: classID)) { Text($0.title).tag(Optional($0.id)) } }.tint(.ink)
                    DatePicker("Teaching day", selection: $date, in: ...Date(), displayedComponents: .date).font(.subheadline)
                }
            }
            if students.isEmpty { EmptyCard(icon: "person.badge.clock", title: "Choose your class.", message: "Select a class with students to begin taking attendance.") }
            else {
                HStack(spacing: 23) {
                    ProgressRing(value: Double(marked) / Double(max(students.count, 1)), size: 70, line: 4, dark: true, label: "\(marked)/\(students.count)")
                    VStack(alignment: .leading, spacing: 10) { Kicker(text: "Register completion", color: .champagne); Text("\(students.filter { store.attendance($0.id, on: date) == .present }.count) present").font(.system(size: 26, design: .serif)).foregroundStyle(Color.paper); Text("\(students.count - marked) students still to record").font(.system(size: 10)).foregroundStyle(Color.paper.opacity(0.5)) }
                    Spacer(minLength: 0)
                }.padding(23).navySurface(radius: 23)
                HStack { SectionLabel(title: "Class register", caption: "\(marked)/\(students.count) recorded"); Spacer() }
                Button("Mark all present", systemImage: "checkmark.circle") { store.markAll(students, on: date, as: .present) }.buttonStyle(GoldButton())
                ForEach(students) { student in
                    PaperCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 13) { Avatar(name: student.title, size: 40); NavigationLink(value: student) { VStack(alignment: .leading, spacing: 5) { Text(student.title).font(.system(size: 20, design: .serif)).foregroundStyle(Color.ink); Text(store.attendance(student.id, on: date) == nil ? "AWAITING CHECK-IN" : "RECORDED").font(.system(size: 6, weight: .medium)).tracking(1.2).foregroundStyle(Color.secondaryInk) } }; Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Color.gold) }
                            HStack(spacing: 6) {
                                ForEach(Presence.allCases, id: \.self) { presence in
                                    let selected = store.attendance(student.id, on: date) == presence
                                    Button { withAnimation(.easeInOut(duration: 0.15)) { if selected { _ = store.clearAttendance(studentID: student.id, on: date) } else { _ = store.mark(student, on: date, as: presence) } } } label: { VStack(spacing: 7) { Image(systemName: presence == .present ? "checkmark" : presence == .absent ? "xmark" : presence == .late ? "clock" : "minus").font(.system(size: 12, weight: .light)); Text(presence.rawValue).font(.system(size: 8, weight: .medium)) }.frame(maxWidth: .infinity).padding(.vertical, 13).background(selected ? Color.ink : Color.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(selected ? Color.champagne : Color.secondaryInk).overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.gold.opacity(0.3) : .clear, lineWidth: 0.7)) }.accessibilityLabel("\(student.title), \(presence.rawValue)").accessibilityAddTraits(selected ? .isSelected : [])
                                }
                            }
                        }
                    }
                }
            }
            NavigationLink(value: Screen.attendanceHistory) { Label("View attendance history", systemImage: "clock.arrow.circlepath").font(.subheadline) }
            Text("Changes are saved as you mark. Tap the selected mark to clear it. Attendance is recorded once per student per day.").font(.caption).foregroundStyle(Color.secondaryInk)
        }.navigationTitle("Attendance").navigationBarTitleDisplayMode(.inline)
            .onAppear { if classID == nil { classID = store.items(.classroom).first?.id }; if date > Date() { date = Date() } }
    }
}
struct AttendanceHistoryPage: View {
    @EnvironmentObject var store: OrganizerStore
    @State private var classID: UUID?
    var marks: [AttendanceMark] { store.workspace.attendance.filter { classID == nil || $0.classID == classID }.sorted { $0.date > $1.date } }
    var dates: [Date] { Array(Set(marks.map { Calendar.current.startOfDay(for: $0.date) })).sorted(by: >) }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "The daily record", title: "Attendance history.")
            Picker("Class", selection: $classID) { Text("All classes").tag(nil as UUID?); ForEach(store.items(.classroom, archived: false) + store.items(.classroom, archived: true)) { Text($0.title).tag(Optional($0.id)) } }
            if marks.isEmpty { EmptyCard(icon: "clock", title: "Your record starts here.", message: "Daily attendance will appear here after you mark a class.") }
            ForEach(dates, id: \.self) { date in
                SectionLabel(title: date.formatted(date: .abbreviated, time: .omitted))
                PaperCard { VStack(spacing: 15) { ForEach(marks.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }) { mark in HStack { Text(store.name(mark.studentID)).font(.subheadline).foregroundStyle(Color.ink); Spacer(); StatusPill(text: mark.presence.rawValue, color: mark.presence == .absent ? .gold : .sage) } } } }
            }
        }.navigationTitle("Attendance History")
    }
}
struct DeadlinesPage: View {
    @EnvironmentObject var store: OrganizerStore
    var entries: [Entry] { store.workspace.entries.filter { !$0.archived && !$0.completed && [.homework, .assessment, .task, .reminder].contains($0.kind) }.sorted { $0.date < $1.date } }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "One step ahead", title: "Upcoming deadlines.", subtitle: "A clear view of what needs your attention.")
            if entries.isEmpty { EmptyCard(icon: "checkmark.circle", title: "All clear for now.", message: "Open homework, tests, tasks and reminders will appear here.") }
            ForEach(entries) { entry in NavigationLink(value: entry) { PaperCard { VStack(alignment: .leading, spacing: 12) { StatusPill(text: entry.date < Date() ? "Overdue" : "Upcoming", color: entry.date < Date() ? .gold : .sage); EntryRow(entry: entry) } } }.buttonStyle(.plain) }
        }.navigationTitle("Deadlines")
    }
}
