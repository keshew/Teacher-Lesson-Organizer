import SwiftUI

extension Color {
    static let ink = Color(red: 0.065, green: 0.12, blue: 0.17)
    static let paper = Color(red: 0.955, green: 0.947, blue: 0.925)
    static let gold = Color(red: 0.69, green: 0.56, blue: 0.35)
    static let champagne = Color(red: 0.88, green: 0.79, blue: 0.61)
    static let sage = Color(red: 0.34, green: 0.48, blue: 0.43)
    static let secondaryInk = Color(red: 0.44, green: 0.47, blue: 0.47)
    static let fineLine = Color(red: 0.86, green: 0.85, blue: 0.81)
    static let mutedRose = Color(red: 0.67, green: 0.42, blue: 0.37)
}
struct Kicker: View {
    var text: String
    var color: Color = .gold
    var body: some View {
        Text(text.uppercased()).font(.system(size: 9, weight: .semibold)).tracking(2.1).foregroundStyle(color).fixedSize(horizontal: false, vertical: true)
    }
}
struct EditorialTitle: View {
    var eyebrow: String
    var title: String
    var subtitle: String = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) { Rectangle().fill(Color.gold).frame(width: 24, height: 1); Kicker(text: eyebrow) }
            Text(title).font(.system(size: 37, weight: .regular, design: .serif)).tracking(-1.2).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            if !subtitle.isEmpty { Text(subtitle).font(.system(size: 13)).foregroundStyle(Color.secondaryInk).lineSpacing(5).fixedSize(horizontal: false, vertical: true) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
struct Emblem: View {
    var size: CGFloat = 56
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26).fill(LinearGradient(colors: [.ink, Color(red: 0.16, green: 0.25, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.17).stroke(Color.champagne.opacity(0.5), lineWidth: 0.7).padding(size * 0.13)
            Text("T").font(.system(size: size * 0.58, weight: .regular, design: .serif)).foregroundStyle(Color.champagne).offset(y: -1)
        }.frame(width: size, height: size)
    }
}
struct ArchitecturalLines: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<7 {
                let offset = CGFloat(i) * 25
                let rect = CGRect(x: size.width * 0.54 + offset, y: -size.height * 0.34 + offset, width: size.width * 0.88, height: size.height * 1.8)
                context.stroke(Path(ellipseIn: rect), with: .color(.champagne.opacity(0.065)), lineWidth: 0.7)
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
struct NavySurface: ViewModifier {
    var radius: CGFloat = 26
    func body(content: Content) -> some View {
        content.background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(colors: [Color(red: 0.12, green: 0.21, blue: 0.26), .ink, Color(red: 0.065, green: 0.11, blue: 0.15)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [.champagne.opacity(0.10), .clear], center: .topTrailing, startRadius: 5, endRadius: 300)
                ArchitecturalLines()
            }.clipShape(RoundedRectangle(cornerRadius: radius))
        }
        .overlay(RoundedRectangle(cornerRadius: radius).stroke(LinearGradient(colors: [.white.opacity(0.19), .champagne.opacity(0.08), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8))
        .shadow(color: .ink.opacity(0.16), radius: 20, x: 0, y: 12)
    }
}
extension View {
    func navySurface(radius: CGFloat = 26) -> some View { modifier(NavySurface(radius: radius)) }
}
struct PaperCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.white, Color(red: 0.992, green: 0.988, blue: 0.977)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.9), lineWidth: 1))
            .shadow(color: .ink.opacity(0.035), radius: 16, x: 0, y: 7)
    }
}
struct SectionLabel: View {
    var title: String
    var caption: String = ""
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title).font(.system(size: 24, design: .serif)).tracking(-0.5).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 3)
            if !caption.isEmpty { Text(caption).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondaryInk).multilineTextAlignment(.trailing) }
        }.padding(.top, 5)
    }
}
struct GoldButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).tracking(0.3).frame(maxWidth: .infinity).padding(.vertical, 18)
            .foregroundStyle(Color.champagne).background(LinearGradient(colors: [Color(red: 0.15, green: 0.24, blue: 0.29), .ink], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Color.champagne.opacity(0.24), lineWidth: 0.7))
            .shadow(color: .ink.opacity(0.12), radius: 10, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
struct QuietPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.975 : 1).opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
struct RoundIcon: View {
    var icon: String
    var dark = false
    var body: some View {
        Image(systemName: icon).font(.system(size: 16, weight: .regular)).foregroundStyle(dark ? Color.champagne : .ink)
            .frame(width: 44, height: 44).background(dark ? .white.opacity(0.08) : .white.opacity(0.7), in: Circle())
            .overlay(Circle().stroke(dark ? .white.opacity(0.10) : Color.fineLine.opacity(0.55), lineWidth: 0.7))
    }
}
struct Avatar: View {
    var name: String
    var size: CGFloat = 43
    var dark = false
    var index: Int { name.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 3 }
    var tone: Color { [.sage, .gold, Color(red: 0.37, green: 0.48, blue: 0.59)][index] }
    var body: some View {
        Text(name.split(separator: " ").prefix(2).compactMap { $0.first.map(String.init) }.joined())
            .font(.system(size: size * 0.33, weight: .medium, design: .serif)).foregroundStyle(dark ? Color.champagne : tone)
            .frame(width: size, height: size).background(dark ? Color(red: 0.18, green: 0.27, blue: 0.30) : tone.opacity(0.10), in: Circle())
            .overlay(Circle().stroke(dark ? Color.champagne.opacity(0.25) : tone.opacity(0.2), lineWidth: 1))
    }
}
struct ProgressRing: View {
    var value: Double
    var size: CGFloat = 76
    var line: CGFloat = 5
    var dark = false
    var label: String = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    var body: some View {
        ZStack {
            Circle().stroke(dark ? .white.opacity(0.09) : Color.gold.opacity(0.12), lineWidth: line)
            Circle().trim(from: 0, to: appeared ? min(max(value, 0), 1) : 0)
                .stroke(AngularGradient(colors: [.gold, .champagne, .gold], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)), style: StrokeStyle(lineWidth: line, lineCap: .round)).rotationEffect(.degrees(-90))
            if !label.isEmpty { Text(label).font(.system(size: size * 0.24, weight: .regular, design: .serif)).foregroundStyle(dark ? Color.paper : .ink) }
        }.frame(width: size, height: size).padding(line / 2)
            .onAppear { withAnimation(reduceMotion ? nil : .easeOut(duration: 0.85)) { appeared = true } }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.45), value: value)
            .accessibilityElement(children: .ignore).accessibilityLabel("\(Int(value * 100)) percent")
    }
}
struct EmptyCard: View {
    var icon: String
    var title: String
    var message: String
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack { Image(systemName: icon).font(.system(size: 25, weight: .ultraLight)).foregroundStyle(Color.gold).frame(width: 60, height: 60).background(Color.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 18)); Spacer(); Text("01").font(.system(size: 46, weight: .ultraLight, design: .serif)).foregroundStyle(Color.gold.opacity(0.18)) }
            Text(title).font(.system(size: 27, design: .serif)).tracking(-0.6).foregroundStyle(Color.ink)
            Text(message).font(.system(size: 13)).foregroundStyle(Color.secondaryInk).lineSpacing(5)
            Rectangle().fill(LinearGradient(colors: [.gold.opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)).frame(height: 1)
        }.padding(25).frame(maxWidth: .infinity, alignment: .leading).background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 25))
            .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.gold.opacity(0.15), lineWidth: 0.7))
    }
}
struct StatusPill: View {
    var text: String
    var color: Color = .sage
    var body: some View { HStack(spacing: 5) { Circle().fill(color).frame(width: 4, height: 4); Text(text).font(.system(size: 9, weight: .medium)).tracking(0.2) }.padding(.horizontal, 9).padding(.vertical, 6).foregroundStyle(color).background(color.opacity(0.08), in: Capsule()).overlay(Capsule().stroke(color.opacity(0.13), lineWidth: 0.5)) }
}
struct StatTile: View {
    var value: String
    var label: String
    var icon: String
    var body: some View {
        PaperCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack { Image(systemName: icon).font(.system(size: 17, weight: .light)).foregroundStyle(Color.gold); Spacer(minLength: 0); Rectangle().fill(Color.gold.opacity(0.3)).frame(width: 13, height: 1) }
                Text(value).font(.system(size: 34, design: .serif)).tracking(-1.3).foregroundStyle(Color.ink).contentTransition(.numericText())
                Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(Color.secondaryInk).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
struct EntryRow: View {
    @EnvironmentObject var store: OrganizerStore
    var entry: Entry
    var body: some View {
        HStack(spacing: 14) {
            if entry.kind == .student { Avatar(name: entry.title, size: 45) }
            else { Image(systemName: entry.kind.icon).font(.system(size: 18, weight: .light)).foregroundStyle(Color.gold).frame(width: 45, height: 49).background(Color.gold.opacity(0.07), in: RoundedRectangle(cornerRadius: 13)).overlay(RoundedRectangle(cornerRadius: 13).stroke(Color.gold.opacity(0.1), lineWidth: 0.7)) }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.ink).lineLimit(2)
                Text(subtitle).font(.system(size: 10)).foregroundStyle(Color.secondaryInk).lineLimit(1)
            }
            Spacer(minLength: 3)
            if entry.completed { Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .light)).foregroundStyle(Color.sage) }
            else if entry.kind == .grade { Text("\(Int(entry.percentage))%").font(.system(size: 22, design: .serif)).foregroundStyle(Color.sage) }
            else { Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .medium)).foregroundStyle(Color.gold) }
        }.padding(.vertical, 4).contentShape(Rectangle())
    }
    var subtitle: String {
        if entry.kind == .student { return store.name(entry.classID) }
        if entry.kind.hasDate { return entry.date.formatted(date: .abbreviated, time: entry.kind == .lesson ? .shortened : .omitted) }
        return entry.detail.isEmpty ? entry.kind.singular : entry.detail
    }
}
struct Page<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 25) { content }.padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 56).frame(maxWidth: 760).frame(maxWidth: .infinity) }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden).background(Color.paper)
    }
}
struct PremiumSegment: View {
    var options: [String]
    @Binding var selection: String
    @Namespace private var selectionAnimation
    var body: some View {
        HStack(spacing: 3) {
            ForEach(options, id: \.self) { option in
                Button { withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { selection = option } } label: {
                    Text(option).font(.system(size: 11, weight: selection == option ? .semibold : .regular)).foregroundStyle(selection == option ? Color.paper : .secondaryInk).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background { if selection == option { RoundedRectangle(cornerRadius: 13).fill(Color.ink).matchedGeometryEffect(id: "selection", in: selectionAnimation) } }
                }.buttonStyle(.plain).accessibilityAddTraits(selection == option ? .isSelected : [])
            }
        }.padding(4).background(Color.ink.opacity(0.035), in: RoundedRectangle(cornerRadius: 17))
    }
}

struct WelcomeArtwork: View {
    var step: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false
    var body: some View {
        ZStack {
            Circle().fill(RadialGradient(colors: [.gold.opacity(0.13), .gold.opacity(0.025), .clear], center: .center, startRadius: 10, endRadius: 165)).frame(width: 330, height: 330)
            Circle().stroke(Color.gold.opacity(0.18), lineWidth: 0.6).frame(width: 270, height: 270)
            Circle().trim(from: 0.12, to: 0.7).stroke(Color.gold.opacity(0.25), lineWidth: 0.6).frame(width: 310, height: 310).rotationEffect(.degrees(Double(step) * 40))
            RoundedRectangle(cornerRadius: 15).fill(Color(red: 0.86, green: 0.82, blue: 0.72)).frame(width: 178, height: 224).rotationEffect(.degrees(9)).offset(x: 16, y: 6)
            RoundedRectangle(cornerRadius: 15).fill(Color(red: 0.99, green: 0.98, blue: 0.95)).frame(width: 178, height: 224).rotationEffect(.degrees(3)).offset(x: 9, y: 7)
            ZStack {
                RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [Color(red: 0.17, green: 0.27, blue: 0.32), .ink], startPoint: .topLeading, endPoint: .bottomTrailing))
                ArchitecturalLines().clipShape(RoundedRectangle(cornerRadius: 15))
                RoundedRectangle(cornerRadius: 10).stroke(Color.champagne.opacity(0.35), lineWidth: 0.6).padding(10)
                RoundedRectangle(cornerRadius: 7).stroke(Color.champagne.opacity(0.1), lineWidth: 0.5).padding(14)
                Rectangle().fill(LinearGradient(colors: [.gold.opacity(0.7), .champagne, .gold], startPoint: .leading, endPoint: .trailing)).frame(width: 3).offset(x: -70)
                VStack(spacing: 15) {
                    Text("T").font(.system(size: 63, design: .serif)).foregroundStyle(LinearGradient(colors: [.champagne, .gold], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Rectangle().fill(Color.gold.opacity(0.6)).frame(width: 33, height: 0.7)
                    Text(["THE LESSON EDIT", "EVERY INDIVIDUAL", "TIME, CONSIDERED"][step]).font(.system(size: 7, weight: .medium)).tracking(2).foregroundStyle(Color.champagne)
                    Image(systemName: ["book.pages", "person.2", "calendar"][step]).font(.system(size: 19, weight: .ultraLight)).foregroundStyle(Color.champagne.opacity(0.6))
                }.padding(.leading, 10)
                BookmarkRibbon().fill(LinearGradient(colors: [.champagne, .gold], startPoint: .leading, endPoint: .trailing)).frame(width: 19, height: 46).offset(x: 48, y: -91)
            }.frame(width: 183, height: 232).rotationEffect(.degrees(revealed ? -9 : -4)).offset(x: -8, y: revealed ? -3 : 5).shadow(color: .ink.opacity(0.25), radius: 19, x: 10, y: 19)
            Image(systemName: "sparkle").font(.system(size: 19, weight: .ultraLight)).foregroundStyle(Color.gold).offset(x: 130, y: -85)
            Circle().fill(Color.gold.opacity(0.5)).frame(width: 3, height: 3).offset(x: -125, y: 70)
        }.onAppear { withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.7)) { revealed = true } }
    }
}
struct BookmarkRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(); path.move(to: .zero); path.addLine(to: CGPoint(x: rect.width, y: 0)); path.addLine(to: CGPoint(x: rect.width, y: rect.height)); path.addLine(to: CGPoint(x: rect.midX, y: rect.height - 9)); path.addLine(to: CGPoint(x: 0, y: rect.height)); path.closeSubpath(); return path
    }
}
