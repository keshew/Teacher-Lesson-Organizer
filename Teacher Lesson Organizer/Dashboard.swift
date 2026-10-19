import SwiftUI
import Combine
import Charts

struct WeekLoad: Identifiable {
    var date: Date
    var minutes: Int
    var id: Date { date }
}
struct DashboardView: View {
    @EnvironmentObject var store: OrganizerStore
    @State private var create: EntryKind?
    @State private var now = Date()
    var today: [Entry] { store.items(.lesson).filter { Calendar.current.isDateInToday($0.date) }.sorted { $0.date < $1.date } }
    var tasks: [Entry] { store.items(.task).filter { !$0.completed }.sorted { $0.date < $1.date } }
    var spotlight: Entry? { store.items(.lesson).filter { !$0.completed && $0.date >= now }.sorted { $0.date < $1.date }.first ?? today.last }
    var week: [WeekLoad] {
        let start = Calendar.current.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return (0..<7).compactMap { index in
            guard let date = Calendar.current.date(byAdding: .day, value: index, to: start) else { return nil }
            let minutes = store.items(.lesson).filter { Calendar.current.isDate($0.date, inSameDayAs: date) }.reduce(0) { $0 + $1.duration }
            return WeekLoad(date: date, minutes: minutes)
        }
    }
    var dayComplete: Int { today.filter(\.completed).count }
    var body: some View {
        Page {
            masthead
            VStack(alignment: .leading, spacing: 11) {
                HStack { Kicker(text: now.formatted(.dateTime.weekday(.wide).month(.wide).day())); Spacer(); Circle().fill(Color.sage).frame(width: 5, height: 5); Text("ON DEVICE").font(.system(size: 8, weight: .medium)).tracking(1.2).foregroundStyle(Color.secondaryInk) }
                Text(store.workspace.teacher.isEmpty ? "The daily edit." : "Your day, \(store.workspace.teacher.components(separatedBy: " ").first ?? store.workspace.teacher).")
                    .font(.system(size: 42, design: .serif)).tracking(-1.8).foregroundStyle(Color.ink)
            }.padding(.top, 2)
            if let lesson = spotlight { NavigationLink(value: lesson) { focusCard(lesson) }.buttonStyle(QuietPress()) }
            else { emptyFocus }
            overview
            weeklyRhythm
            HStack { SectionLabel(title: "Today's agenda", caption: "\(today.count) lessons"); NavigationLink(value: Screen.schedule) { Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Color.gold) }.accessibilityLabel("Open schedule") }
            if today.isEmpty {
                PaperCard { HStack(spacing: 15) { RoundIcon(icon: "sun.horizon"); VStack(alignment: .leading, spacing: 6) { Text("An open page").font(.system(size: 20, design: .serif)); Text("No lessons planned for today.").font(.system(size: 11)).foregroundStyle(Color.secondaryInk) }; Spacer(); Button { create = .lesson } label: { Image(systemName: "plus").foregroundStyle(Color.gold) }.accessibilityLabel("Plan a lesson") } }
            } else {
                VStack(spacing: 0) { ForEach(Array(today.enumerated()), id: \.element.id) { index, lesson in NavigationLink(value: lesson) { AgendaLessonCard(lesson: lesson, index: index + 1, last: index == today.count - 1) }.buttonStyle(QuietPress()) } }
            }
            HStack(spacing: 12) {
                actionTile("Attendance", detail: "The daily register", icon: "person.badge.clock", screen: .attendance, dark: true)
                actionTile("Progress", detail: "Learning in focus", icon: "chart.xyaxis.line", screen: .statistics, dark: false)
            }
            HStack { SectionLabel(title: "Your priorities", caption: "\(tasks.count) open"); NavigationLink(value: Screen.todo) { Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Color.gold) }.accessibilityLabel("Open tasks") }
            PaperCard {
                if tasks.isEmpty { HStack { Image(systemName: "checkmark.seal").foregroundStyle(Color.sage); Text("Everything is in hand.").font(.system(size: 14, design: .serif)); Spacer(); Button { create = .task } label: { Image(systemName: "plus").foregroundStyle(Color.gold) }.accessibilityLabel("Add task") } }
                else { VStack(spacing: 18) { ForEach(tasks.prefix(3)) { item in
                    HStack(spacing: 14) {
                        Button { withAnimation(.spring(response: 0.35)) { _ = store.toggle(item) } } label: { Image(systemName: "circle").font(.system(size: 22, weight: .ultraLight)).foregroundStyle(Color.gold) }.accessibilityLabel("Complete \(item.title)")
                        NavigationLink(value: item) { VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink); Text(item.date.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(Color.secondaryInk) }.frame(maxWidth: .infinity, alignment: .leading) }
                        if item.date < now { Circle().fill(Color.mutedRose).frame(width: 5, height: 5) }
                    }
                } } }
            }
            HStack(spacing: 10) { Rectangle().fill(Color.fineLine).frame(height: 0.5); Emblem(size: 22); Rectangle().fill(Color.fineLine).frame(height: 0.5) }.padding(.vertical, 8).accessibilityHidden(true)
        }.onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { now = $0 }
            .toolbar(.hidden, for: .navigationBar).sheet(item: $create) { EntryEditor(kind: $0) }
    }
    var masthead: some View {
        HStack(spacing: 12) {
            Emblem(size: 37)
            VStack(alignment: .leading, spacing: 3) { Text("TEACHER").font(.system(size: 11, weight: .semibold)).tracking(3.2); Text("PERSONAL ORGANIZER").font(.system(size: 7, weight: .medium)).tracking(1.6).foregroundStyle(Color.secondaryInk) }.foregroundStyle(Color.ink)
            Spacer()
            NavigationLink(value: Screen.search) { RoundIcon(icon: "magnifyingglass") }.accessibilityLabel("Search workspace")
            Menu { Button("Plan a lesson") { create = .lesson }; Button("Add a student") { create = .student }; Button("Add a task") { create = .task }; Button("Add a reminder") { create = .reminder } } label: { RoundIcon(icon: "plus", dark: true).background(Color.ink, in: Circle()) }.accessibilityLabel("Create a record")
        }.padding(.bottom, 3)
    }
    func focusCard(_ lesson: Entry) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Kicker(text: lesson.date >= now ? "Up next · \(lesson.date.formatted(.dateTime.weekday(.abbreviated)))" : "Today's latest lesson", color: .champagne); Spacer(); Text(lesson.date.formatted(date: .omitted, time: .shortened)).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.paper.opacity(0.75)) }
            Text(lesson.title).font(.system(size: 31, design: .serif)).tracking(-0.7).foregroundStyle(Color.paper).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: 12) {
                Label(store.name(lesson.classID), systemImage: "person.2").lineLimit(1)
                Circle().fill(Color.champagne.opacity(0.4)).frame(width: 3, height: 3)
                Text("\(lesson.duration) min")
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right").foregroundStyle(Color.champagne)
            }.font(.system(size: 11)).foregroundStyle(Color.paper.opacity(0.65))
            Rectangle().fill(.white.opacity(0.12)).frame(height: 0.5)
            HStack(spacing: 12) {
                ProgressRing(value: Double(dayComplete) / Double(max(today.count, 1)), size: 34, line: 2.5, dark: true)
                VStack(alignment: .leading, spacing: 4) { Text("TODAY'S MOMENTUM").font(.system(size: 7, weight: .medium)).tracking(1.8).foregroundStyle(Color.champagne); Text("\(dayComplete) of \(today.count) lessons completed").font(.system(size: 10)).foregroundStyle(Color.paper.opacity(0.65)) }
                Spacer()
                Text("\(today.reduce(0) { $0 + $1.duration })").font(.system(size: 25, design: .serif)).foregroundStyle(Color.paper) + Text(" min").font(.system(size: 9)).foregroundStyle(Color.paper.opacity(0.5))
            }
        }.padding(24).navySurface()
    }
    var emptyFocus: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Kicker(text: "Your teaching day", color: .champagne); Spacer(); Image(systemName: "sun.max").font(.system(size: 24, weight: .ultraLight)).foregroundStyle(Color.champagne) }
            Text("Make space for\nyour next great lesson.").font(.system(size: 31, design: .serif)).foregroundStyle(Color.paper)
            Button { create = .lesson } label: { HStack { Text("Plan a lesson"); Spacer(); Image(systemName: "arrow.right") }.font(.system(size: 12, weight: .medium)).foregroundStyle(Color.champagne).padding(.top, 9) }
        }.padding(25).navySurface()
    }
    var overview: some View {
        HStack(spacing: 0) {
            summary("\(store.items(.classroom).count)", "CLASSES", screen: .classes)
            Rectangle().fill(Color.fineLine).frame(width: 0.5, height: 33)
            summary("\(store.items(.student).count)", "STUDENTS", screen: .students)
            Rectangle().fill(Color.fineLine).frame(width: 0.5, height: 33)
            summary("\(store.items(.homework).filter { !$0.completed }.count)", "ASSIGNMENTS", screen: .homework)
        }.padding(.vertical, 5)
    }
    func summary(_ value: String, _ label: String, screen: Screen) -> some View {
        NavigationLink(value: screen) { VStack(spacing: 6) { Text(value).font(.system(size: 31, design: .serif)).tracking(-1).foregroundStyle(Color.ink); Text(label).font(.system(size: 7, weight: .semibold)).tracking(1.4).foregroundStyle(Color.secondaryInk) }.frame(maxWidth: .infinity) }.buttonStyle(QuietPress())
    }
    var weeklyRhythm: some View {
        let total = week.reduce(0) { $0 + $1.minutes }
        return NavigationLink(value: Screen.schedule) {
            PaperCard {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 7) { Kicker(text: "Weekly rhythm"); HStack(alignment: .firstTextBaseline, spacing: 5) { Text("\(total / 60)").font(.system(size: 32, design: .serif)).tracking(-1); Text("h  \(total % 60)m planned").font(.system(size: 10)).foregroundStyle(Color.secondaryInk) } }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) { Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Color.gold); Text("THIS WEEK").font(.system(size: 7, weight: .medium)).tracking(1.4).foregroundStyle(Color.secondaryInk) }
                    }
                    Chart(week) { day in
                        BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.minutes), width: .ratio(0.42)).cornerRadius(4)
                            .foregroundStyle(Calendar.current.isDateInToday(day.date) ? LinearGradient(colors: [.champagne, .gold], startPoint: .top, endPoint: .bottom) : LinearGradient(colors: [Color.ink.opacity(0.80), .ink], startPoint: .top, endPoint: .bottom))
                    }.chartYScale(domain: 0...max(week.map(\.minutes).max() ?? 60, 60)).chartYAxis(.hidden)
                        .chartXAxis { AxisMarks(values: week.map(\.date)) { value in AxisValueLabel(format: .dateTime.weekday(.narrow)).font(.system(size: 9)).foregroundStyle(Color.secondaryInk) } }.frame(height: 75)
                    HStack(spacing: 5) { Circle().fill(Color.gold).frame(width: 4, height: 4); Text(total == 0 ? "Plan lessons to build your weekly view" : "\(week.filter { $0.minutes > 0 }.count) teaching days · \(store.items(.lesson).filter { lesson in week.contains { Calendar.current.isDate($0.date, inSameDayAs: lesson.date) } }.count) lessons").font(.system(size: 9)).foregroundStyle(Color.secondaryInk) }
                }.foregroundStyle(Color.ink)
            }
        }.buttonStyle(QuietPress())
    }
    func actionTile(_ title: String, detail: String, icon: String, screen: Screen, dark: Bool) -> some View {
        NavigationLink(value: screen) {
            VStack(alignment: .leading, spacing: 20) {
                HStack { Image(systemName: icon).font(.system(size: 22, weight: .ultraLight)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)) }.foregroundStyle(dark ? Color.champagne : .gold)
                VStack(alignment: .leading, spacing: 6) { Text(title).font(.system(size: 21, design: .serif)).foregroundStyle(dark ? Color.paper : .ink); Text(detail).font(.system(size: 9)).foregroundStyle(dark ? Color.paper.opacity(0.55) : .secondaryInk) }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(dark ? Color.ink : Color.gold.opacity(0.10), in: RoundedRectangle(cornerRadius: 22)).overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.gold.opacity(0.14), lineWidth: 0.6))
        }.buttonStyle(QuietPress())
    }
}
struct AgendaLessonCard: View {
    @EnvironmentObject var store: OrganizerStore
    var lesson: Entry
    var index: Int = 1
    var last = true
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(alignment: .trailing, spacing: 5) { Text(lesson.date.formatted(.dateTime.hour().minute())).font(.system(size: 12, weight: .medium)).foregroundStyle(Color.ink); Text("\(lesson.duration) MIN").font(.system(size: 7, weight: .medium)).tracking(1).foregroundStyle(Color.secondaryInk) }.frame(width: 50, alignment: .trailing).padding(.top, 20)
            VStack(spacing: 0) { Circle().fill(lesson.completed ? Color.sage : Color.gold).frame(width: 6, height: 6).padding(.top, 24); Rectangle().fill(Color.fineLine.opacity(last ? 0 : 1)).frame(width: 0.7) }.frame(width: 6)
            VStack(alignment: .leading, spacing: 13) {
                HStack { Kicker(text: store.entry(lesson.subjectID)?.title ?? "Lesson plan"); Spacer(minLength: 0); Text(String(format: "%02d", index)).font(.system(size: 10, design: .serif)).foregroundStyle(Color.gold) }
                Text(lesson.title).font(.system(size: 22, design: .serif)).tracking(-0.4).foregroundStyle(Color.ink).lineLimit(2)
                HStack { Text(store.name(lesson.classID)).font(.system(size: 10)).foregroundStyle(Color.secondaryInk); Spacer(); Image(systemName: lesson.completed ? "checkmark.circle" : "arrow.up.right").font(.system(size: 12)).foregroundStyle(lesson.completed ? Color.sage : .gold) }
            }.padding(18).background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 20)).padding(.bottom, 11)
        }.fixedSize(horizontal: false, vertical: true)
    }
}

struct WorkspaceView: View {
    @EnvironmentObject var store: OrganizerStore
    let sections: [(String, [Screen])] = [
        ("Plan & prepare", [.lessons, .templates, .subjects, .schedule, .upcoming]),
        ("People & connections", [.students, .attendance, .attendanceHistory, .notes, .behavior]),
        ("Learning & progress", [.grades, .categories, .tests, .results, .statistics, .classProgress, .studentProgress]),
        ("Library & priorities", [.materials, .attachments, .todo, .reminders, .deadlines]),
        ("Your workspace", [.search, .archive, .settings])
    ]
    var body: some View {
        Page {
            HStack { EditorialTitle(eyebrow: "Your personal collection", title: "The studio.", subtitle: "Everything you need, thoughtfully arranged."); NavigationLink(value: Screen.settings) { RoundIcon(icon: "slider.horizontal.3") }.accessibilityLabel("Settings") }
            HStack(spacing: 13) {
                module("Lesson library", count: store.items(.lesson).count, icon: "books.vertical", screen: .lessons, dark: true)
                module("Resources", count: store.items(.material).count, icon: "folder", screen: .materials, dark: false)
            }
            ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                VStack(alignment: .leading, spacing: 13) {
                    HStack { Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .serif)).foregroundStyle(Color.gold); SectionLabel(title: section.0) }
                    PaperCard { VStack(spacing: 0) { ForEach(section.1) { screen in
                        NavigationLink(value: screen) {
                            HStack(spacing: 15) { Image(systemName: screen.icon).font(.system(size: 17, weight: .light)).foregroundStyle(Color.gold).frame(width: 24); Text(screen.rawValue).font(.system(size: 13)).foregroundStyle(Color.ink); Spacer(); if let count = recordCount(for: screen) { Text("\(count)").font(.system(size: 11, design: .serif)).foregroundStyle(Color.secondaryInk) }; Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(Color.gold) }.padding(.vertical, 15)
                        }.buttonStyle(QuietPress())
                        if screen != section.1.last { Rectangle().fill(Color.fineLine.opacity(0.5)).frame(height: 0.5).padding(.leading, 39) }
                    } } }
                }
            }
        }.navigationTitle("Workspace").navigationBarTitleDisplayMode(.inline)
    }
    func recordCount(for screen: Screen) -> Int? {
        guard let kind = screen.kind else { return nil }
        let records = store.items(kind)
        if screen == .attachments { return records.filter { $0.fileName != nil }.count }
        if screen == .upcoming { return records.filter { $0.date >= Date() && !$0.completed }.count }
        return records.count
    }
    func module(_ title: String, count: Int, icon: String, screen: Screen, dark: Bool) -> some View {
        NavigationLink(value: screen) {
            VStack(alignment: .leading, spacing: 17) {
                HStack { Image(systemName: icon).font(.system(size: 23, weight: .ultraLight)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)) }.foregroundStyle(dark ? Color.champagne : .gold)
                Text("\(count)").font(.system(size: 37, design: .serif)).foregroundStyle(dark ? Color.paper : .ink)
                Text(title).font(.system(size: 11)).foregroundStyle(dark ? Color.paper.opacity(0.6) : .secondaryInk)
            }.padding(21).frame(maxWidth: .infinity, alignment: .leading).background(dark ? Color.ink : .white, in: RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(QuietPress())
    }
}
