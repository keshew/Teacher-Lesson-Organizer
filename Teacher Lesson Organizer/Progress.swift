import SwiftUI
import Charts

struct ScoreBand: Identifiable {
    var title: String
    var count: Int
    var color: Color
    var id: String { title }
}
struct ProgressPage: View {
    @EnvironmentObject var store: OrganizerStore
    var mode: Screen = .statistics
    @State private var selection: UUID?
    @State private var period = "All time"
    @State private var selectedDate: Date?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    init(mode: Screen = .statistics, initialSelection: UUID? = nil) { self.mode = mode; _selection = State(initialValue: initialSelection) }
    var cutoff: Date? { Calendar.current.date(byAdding: .day, value: period == "30 days" ? -30 : -90, to: Date()) }
    var grades: [Entry] {
        store.items(.grade).filter { grade in
            let periodMatch = period == "All time" || grade.date >= (cutoff ?? .distantPast)
            if mode == .classProgress { return periodMatch && selection != nil && grade.classID == selection }
            if mode == .studentProgress { return periodMatch && selection != nil && grade.studentID == selection }
            return periodMatch
        }.sorted { $0.date < $1.date }
    }
    var marks: [AttendanceMark] {
        store.workspace.attendance.filter {
            let periodMatch = period == "All time" || $0.date >= (cutoff ?? .distantPast)
            if mode == .classProgress { return periodMatch && selection != nil && $0.classID == selection }
            if mode == .studentProgress { return periodMatch && selection != nil && $0.studentID == selection }
            return periodMatch
        }
    }
    var weightedAverage: Double? { weighted(grades) }
    func weighted(_ records: [Entry]) -> Double? { store.weightedAverage(records) }
    var trend: [LearningPoint] { store.dailyAverages(grades) }
    var selectedPoint: LearningPoint? { guard let selectedDate else { return nil }; return trend.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) } }
    var delta: Double? { guard let first = trend.first, let last = trend.last, trend.count > 1 else { return nil }; return last.average - first.average }
    var attendanceRate: Double? { marks.isEmpty ? nil : Double(marks.filter { $0.presence == .present || $0.presence == .late }.count) / Double(marks.count) }
    var bands: [ScoreBand] { [ScoreBand(title: "0–49", count: grades.filter { $0.percentage < 50 }.count, color: .mutedRose), ScoreBand(title: "50–64", count: grades.filter { $0.percentage >= 50 && $0.percentage < 65 }.count, color: .gold.opacity(0.5)), ScoreBand(title: "65–79", count: grades.filter { $0.percentage >= 65 && $0.percentage < 80 }.count, color: .gold), ScoreBand(title: "80–100", count: grades.filter { $0.percentage >= 80 }.count, color: .sage)] }
    var dateDomain: ClosedRange<Date> {
        let first = trend.first?.date ?? Calendar.current.startOfDay(for: Date())
        let last = trend.last?.date ?? first
        if first == last { return first.addingTimeInterval(-86400)...last.addingTimeInterval(86400) }
        return first...last
    }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "The learning portfolio", title: title, subtitle: "A clearer perspective on every step forward.")
            if mode != .statistics { selector }
            PremiumSegment(options: ["30 days", "90 days", "All time"], selection: $period)
            performancePanel
            HStack(alignment: .top, spacing: 13) { attendanceSummary; recordSummary }
            if !grades.isEmpty {
                distributionPanel
                if mode == .statistics || mode == .classProgress { classComparison }
                HStack { SectionLabel(title: "Recent assessments", caption: "\(grades.count) records"); Image(systemName: "arrow.down.right").font(.system(size: 11)).foregroundStyle(Color.gold) }
                PaperCard { VStack(spacing: 16) { ForEach(Array(grades.reversed().prefix(5).enumerated()), id: \.element.id) { index, grade in
                    NavigationLink(value: grade) { HStack(spacing: 13) { Text(String(format: "%02d", index + 1)).font(.system(size: 12, design: .serif)).foregroundStyle(Color.gold).frame(width: 22); VStack(alignment: .leading, spacing: 5) { Text(grade.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink); Text("\(store.name(grade.studentID)) · \(grade.date.formatted(.dateTime.month(.abbreviated).day()))").font(.system(size: 9)).foregroundStyle(Color.secondaryInk).lineLimit(1) }; Spacer(); Text("\(Int(grade.percentage))").font(.system(size: 24, design: .serif)).foregroundStyle(Color.ink); Text("%").font(.system(size: 10)).foregroundStyle(Color.gold) } }.buttonStyle(QuietPress())
                    if index < min(grades.count, 5) - 1 { Rectangle().fill(Color.fineLine.opacity(0.6)).frame(height: 0.5) }
                } } }
            }
            if !marks.isEmpty { attendanceBreakdown }
            if mode == .statistics {
                HStack(spacing: 12) { NavigationLink(value: Screen.classProgress) { drilldown("Class portfolios", icon: "rectangle.3.group") }; NavigationLink(value: Screen.studentProgress) { drilldown("Student portfolios", icon: "person") } }.buttonStyle(QuietPress())
            }
            Text("Grade averages reflect category weights. Attendance includes present and late marks; all recorded days remain in the total.").font(.system(size: 9)).foregroundStyle(Color.secondaryInk).lineSpacing(4)
        }.navigationTitle(mode.rawValue).navigationBarTitleDisplayMode(.inline)
            .onAppear { if selection == nil && mode != .statistics { selection = store.items(mode == .classProgress ? .classroom : .student).first?.id } }
            .onChange(of: selection) { _, _ in selectedDate = nil }.onChange(of: period) { _, _ in selectedDate = nil }
    }
    var title: String { mode == .classProgress ? "The class perspective." : mode == .studentProgress ? "A learning journey." : "Progress, in perspective." }
    var selector: some View {
        PaperCard {
            HStack(spacing: 13) {
                if mode == .studentProgress { Avatar(name: store.entry(selection)?.title ?? "Student", size: 42) }
                else { Image(systemName: "rectangle.3.group").font(.system(size: 23, weight: .light)).foregroundStyle(Color.gold) }
                Picker(mode == .classProgress ? "Class" : "Student", selection: $selection) {
                    Text("Choose \(mode == .classProgress ? "a class" : "a student")").tag(nil as UUID?)
                    ForEach(store.choices(mode == .classProgress ? .classroom : .student, including: selection)) { Text($0.title).tag(Optional($0.id)) }
                }.tint(.ink).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
    var performancePanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Kicker(text: selectedPoint == nil ? "Learning performance" : "Daily weighted average", color: .champagne); Spacer(); Image(systemName: "chart.xyaxis.line").font(.system(size: 17, weight: .light)).foregroundStyle(Color.champagne.opacity(0.8)) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text((selectedPoint?.average ?? weightedAverage).map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—").font(.system(size: 57, weight: .regular, design: .serif)).tracking(-2.5).contentTransition(.numericText())
                Text("%").font(.system(size: 22, weight: .ultraLight)).foregroundStyle(Color.champagne)
                Spacer()
                if let delta, selectedPoint == nil { VStack(alignment: .trailing, spacing: 5) { Label("\(abs(delta).formatted(.number.precision(.fractionLength(1)))) pts", systemImage: delta >= 0 ? "arrow.up.right" : "arrow.down.right").font(.system(size: 10, weight: .medium)).foregroundStyle(delta >= 0 ? Color(red: 0.63, green: 0.80, blue: 0.68) : .champagne); Text("FIRST → LATEST DAY").font(.system(size: 6, weight: .medium)).tracking(0.8).foregroundStyle(Color.paper.opacity(0.4)) } }
            }.foregroundStyle(Color.paper)
            Text(selectedPoint.map { $0.date.formatted(.dateTime.month(.wide).day().year()) } ?? "Weighted average · \(grades.count) learning records")
                .font(.system(size: 10)).foregroundStyle(Color.paper.opacity(0.55)).padding(.top, -15)
            Chart {
                ForEach(trend) { point in
                    AreaMark(x: .value("Date", point.date), yStart: .value("Base", 0), yEnd: .value("Average", point.average))
                        .foregroundStyle(LinearGradient(colors: [.champagne.opacity(0.24), .gold.opacity(0.04), .clear], startPoint: .top, endPoint: .bottom)).interpolationMethod(.monotone)
                    LineMark(x: .value("Date", point.date), y: .value("Average", point.average)).foregroundStyle(LinearGradient(colors: [.gold, .champagne], startPoint: .leading, endPoint: .trailing)).lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round)).interpolationMethod(.monotone)
                }
                if let point = selectedPoint ?? trend.last {
                    RuleMark(x: .value("Selected day", point.date)).foregroundStyle(Color.champagne.opacity(0.25)).lineStyle(StrokeStyle(lineWidth: 0.7, dash: [4, 4]))
                    PointMark(x: .value("Date", point.date), y: .value("Average", point.average)).foregroundStyle(Color.champagne).symbolSize(45)
                }
            }.chartYScale(domain: 0...100).chartXScale(domain: dateDomain)
                .chartYAxis { AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { _ in AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 4])).foregroundStyle(.white.opacity(0.10)); AxisValueLabel().font(.system(size: 8)).foregroundStyle(.white.opacity(0.35)) } }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: 3)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 8)).foregroundStyle(.white.opacity(0.4)) } }
                .chartXSelection(value: $selectedDate).frame(height: 170)
                .overlay { if grades.isEmpty { Text("Record a grade to begin your learning portfolio.").font(.system(size: 12, design: .serif)).foregroundStyle(Color.champagne).multilineTextAlignment(.center).padding(24) } }
            HStack { HStack(spacing: 5) { Circle().fill(Color.champagne).frame(width: 4, height: 4); Text("DAILY AVERAGE").tracking(1.1) }; Spacer(); Text(grades.isEmpty ? "NO DATA YET" : "TOUCH TO EXPLORE").tracking(1.1) }.font(.system(size: 6, weight: .medium)).foregroundStyle(Color.paper.opacity(0.4))
        }.padding(24).navySurface()
    }
    var attendanceSummary: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 17) {
                Kicker(text: "Attendance")
                ProgressRing(value: attendanceRate ?? 0, size: 73, line: 4.5, label: attendanceRate.map { "\(Int($0 * 100))%" } ?? "—").frame(maxWidth: .infinity)
                Text("\(marks.filter { $0.presence == .present || $0.presence == .late }.count) of \(marks.count) days attended").font(.system(size: 9)).foregroundStyle(Color.secondaryInk).frame(maxWidth: .infinity)
            }
        }
    }
    var recordSummary: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 17) {
                Kicker(text: "Learning records")
                Text("\(grades.count)").font(.system(size: 49, design: .serif)).tracking(-2).foregroundStyle(Color.ink).frame(height: 78, alignment: .center)
                HStack(spacing: 4) { Circle().fill(Color.sage).frame(width: 4, height: 4); Text("\(Set(grades.compactMap(\.studentID)).count) students represented").font(.system(size: 9)).foregroundStyle(Color.secondaryInk).lineLimit(2) }
            }
        }
    }
    var distributionPanel: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 24) {
                HStack { VStack(alignment: .leading, spacing: 6) { Kicker(text: "Assessment profile"); Text("The range of achievement").font(.system(size: 22, design: .serif)).tracking(-0.4).foregroundStyle(Color.ink) }; Spacer() }
                Chart(bands) { band in
                    BarMark(x: .value("Score range", band.title), y: .value("Records", band.count), width: .ratio(0.46)).cornerRadius(6)
                        .foregroundStyle(LinearGradient(colors: [band.color.opacity(0.6), band.color], startPoint: .top, endPoint: .bottom))
                        .annotation(position: .top, spacing: 8) { Text("\(band.count)").font(.system(size: 13, design: .serif)).foregroundStyle(Color.ink) }
                }.chartYScale(domain: 0...max((bands.map(\.count).max() ?? 1) + 1, 2)).chartYAxis(.hidden)
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.system(size: 9)).foregroundStyle(Color.secondaryInk) } }.frame(height: 145)
                HStack { Text("SCORE BANDS").tracking(1.2); Spacer(); Text("\(grades.count) GRADED RECORDS").tracking(1) }.font(.system(size: 7, weight: .medium)).foregroundStyle(Color.secondaryInk)
            }
        }
    }
    var classComparison: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: mode == .classProgress ? "Individual perspectives" : "Class perspectives")
            PaperCard {
                VStack(spacing: 20) {
                    ForEach(comparisonEntries.prefix(6)) { entry in
                        let records = grades.filter { mode == .classProgress ? $0.studentID == entry.id : $0.classID == entry.id }
                        let average = weighted(records)
                        NavigationLink(value: ContextRoute.progress(mode == .classProgress ? .studentProgress : .classProgress, entry.id)) {
                            VStack(spacing: 9) { HStack { Text(entry.title).font(.system(size: 12)).foregroundStyle(Color.ink); Spacer(); Text(average.map { "\(Int($0))%" } ?? "—").font(.system(size: 15, design: .serif)).foregroundStyle(Color.gold) }; GeometryReader { geometry in ZStack(alignment: .leading) { Capsule().fill(Color.ink.opacity(0.045)); Capsule().fill(LinearGradient(colors: [.gold, .champagne], startPoint: .leading, endPoint: .trailing)).frame(width: geometry.size.width * min(max((average ?? 0) / 100, 0), 1)) } }.frame(height: 4) }
                        }.buttonStyle(QuietPress())
                    }
                }
            }
        }
    }
    var comparisonEntries: [Entry] { mode == .classProgress ? store.items(.student).filter { $0.classID == selection } : store.items(.classroom) }
    var attendanceBreakdown: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(title: "Presence, in detail")
            PaperCard { HStack(spacing: 23) {
                Chart(Presence.allCases, id: \.self) { presence in
                    SectorMark(angle: .value("Days", marks.filter { $0.presence == presence }.count), innerRadius: .ratio(0.76), angularInset: 3).cornerRadius(3).foregroundStyle(presenceColor(presence))
                }.frame(width: 108, height: 108).overlay { VStack(spacing: 3) { Text("\(marks.count)").font(.system(size: 28, design: .serif)).foregroundStyle(Color.ink); Text("DAYS").font(.system(size: 7, weight: .medium)).tracking(1.4).foregroundStyle(Color.secondaryInk) } }
                VStack(spacing: 13) { ForEach(Presence.allCases, id: \.self) { presence in HStack(spacing: 7) { Circle().fill(presenceColor(presence)).frame(width: 5, height: 5); Text(presence.rawValue).font(.system(size: 10)).foregroundStyle(Color.secondaryInk); Spacer(); Text("\(marks.filter { $0.presence == presence }.count)").font(.system(size: 12, weight: .medium)).foregroundStyle(Color.ink) } } }
            } }
        }
    }
    func presenceColor(_ presence: Presence) -> Color { switch presence { case .present: .sage; case .late: .gold; case .absent: .mutedRose; case .excused: Color(red: 0.67, green: 0.72, blue: 0.76) } }
    func drilldown(_ title: String, icon: String) -> some View { VStack(alignment: .leading, spacing: 20) { HStack { Image(systemName: icon).font(.system(size: 20, weight: .light)); Spacer(); Image(systemName: "arrow.up.right").font(.system(size: 9)) }.foregroundStyle(Color.gold); Text(title).font(.system(size: 18, design: .serif)).foregroundStyle(Color.ink) }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(Color.gold.opacity(0.075), in: RoundedRectangle(cornerRadius: 21)) }
}
struct ResultsPage: View {
    @EnvironmentObject var store: OrganizerStore
    @State private var assessmentID: UUID?
    @State private var adding = false
    var results: [Entry] { store.items(.grade).filter { $0.assessmentID != nil && (assessmentID == nil || $0.assessmentID == assessmentID) }.sorted { $0.percentage > $1.percentage } }
    var body: some View {
        Page {
            EditorialTitle(eyebrow: "Evidence of learning", title: "Test results.", subtitle: "Look beyond a score. Find the next step.")
            Picker("Assessment", selection: $assessmentID) { Text("All tests & quizzes").tag(nil as UUID?); ForEach(store.workspace.entries.filter { $0.kind == .assessment }.sorted { $0.title < $1.title }) { Text($0.title + ($0.archived ? " (Archived)" : "")).tag(Optional($0.id)) } }.tint(.ink)
            if !results.isEmpty { HStack(spacing: 12) { StatTile(value: "\(results.count)", label: "Recorded results", icon: "checkmark.seal"); StatTile(value: "\(Int(results.map(\.percentage).reduce(0, +) / Double(results.count)))%", label: "Mean score", icon: "chart.bar") } }
            if results.isEmpty { EmptyCard(icon: "checkmark.seal", title: "Ready for the next insight.", message: "Record grades linked to a test or quiz to see results here.") }
            ForEach(results) { result in NavigationLink(value: result) { PaperCard { VStack(alignment: .leading, spacing: 9) { Text(store.name(result.studentID)).font(.system(size: 21, design: .serif)).foregroundStyle(Color.ink); EntryRow(entry: result) } } }.buttonStyle(.plain) }
            Button("Record test result", systemImage: "plus") { adding = true }.buttonStyle(GoldButton())
        }.navigationTitle("Test Results").sheet(isPresented: $adding) { EntryEditor(kind: .grade, classID: store.entry(assessmentID)?.classID, assessmentID: assessmentID, requiresAssessment: true) }
    }
}
