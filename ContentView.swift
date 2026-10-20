import SwiftUI
import Foundation

struct ContentView: View {
    @State private var expression = "y = 2x + 1"
    @State private var zoom: CGFloat = 1
    @State private var zoomAtStart: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var offsetAtStart = CGSize.zero
    @State private var showAnalysis = true
    @State private var enabledComparisonExpressions: Set<String> = []
    @State private var xStart = -5.0
    @State private var xEnd = 5.0
    @State private var xStep = 1.0
    @State private var selectedLesson = 0
    @FocusState private var expressionFocused: Bool

    private var parsed: MathExpression? { MathExpression(expression: expression) }
    private var visibleRange: Double { 10 / Double(max(zoom, 0.25)) }
    private var xIntercepts: [Double] { roots(for: parsed, in: -visibleRange...visibleRange) }
    private var yIntercept: Double? { parsed?.value(0).flatMapFinite }
    private var vertex: CGPoint? { quadraticVertex(expression) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                graph
                    .frame(minHeight: 300, maxHeight: 390)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                HStack {
                    Label("每格约 \(gridStep, specifier: "%.3g")", systemImage: "ruler")
                    Spacer()
                    Button {
                        withAnimation(.spring) {
                            zoom = 1
                            zoomAtStart = 1
                            offset = .zero
                            offsetAtStart = .zero
                        }
                    } label: {
                        Label("重置", systemImage: "arrow.counterclockwise")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)

                TabView {
                    functionPanel
                        .tabItem { Label("绘图", systemImage: "chart.xyaxis.line") }
                    analysisPanel
                        .tabItem { Label("分析", systemImage: "scope") }
                    tablePanel
                        .tabItem { Label("函数表", systemImage: "tablecells") }
                    learningPanel
                        .tabItem { Label("学习", systemImage: "graduationcap") }
                }
            }
            .navigationTitle("初中函数绘图")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var gridStep: Double {
        let raw = visibleRange / 5
        let power = pow(10, floor(log10(max(raw, 0.0001))))
        let normalized = raw / power
        let nice = normalized < 1.5 ? 1 : (normalized < 3.5 ? 2 : (normalized < 7.5 ? 5 : 10))
        return nice * power
    }

    private var graph: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, canvas in
                let unit = min(canvas.width, canvas.height) / CGFloat(2 * visibleRange)
                let origin = CGPoint(x: canvas.width / 2 + offset.width, y: canvas.height / 2 + offset.height)
                let step = CGFloat(gridStep) * unit
                guard step.isFinite, step > 0 else { return }

                var grid = Path()
                let nx = min(500, Int(canvas.width / step) + 4)
                let ny = min(500, Int(canvas.height / step) + 4)
                for i in (-nx)...nx {
                    let x = origin.x + CGFloat(i) * step
                    if x >= 0 && x <= canvas.width {
                        grid.move(to: CGPoint(x: x, y: 0))
                        grid.addLine(to: CGPoint(x: x, y: canvas.height))
                    }
                }
                for i in (-ny)...ny {
                    let y = origin.y + CGFloat(i) * step
                    if y >= 0 && y <= canvas.height {
                        grid.move(to: CGPoint(x: 0, y: y))
                        grid.addLine(to: CGPoint(x: canvas.width, y: y))
                    }
                }
                context.stroke(grid, with: .color(.gray.opacity(0.2)), lineWidth: 0.7)

                var axes = Path()
                axes.move(to: CGPoint(x: 0, y: origin.y))
                axes.addLine(to: CGPoint(x: canvas.width, y: origin.y))
                axes.move(to: CGPoint(x: origin.x, y: 0))
                axes.addLine(to: CGPoint(x: origin.x, y: canvas.height))
                context.stroke(axes, with: .color(.primary.opacity(0.8)), lineWidth: 1.3)

                for i in (-nx)...nx where i != 0 {
                    let x = origin.x + CGFloat(i) * step
                    if x > 8 && x < canvas.width - 8 {
                        context.draw(Text("\(Double(i) * gridStep, specifier: "%.3g")").font(.system(size: 9)).foregroundColor(.secondary), at: CGPoint(x: x, y: min(canvas.height - 10, max(10, origin.y + 11))))
                    }
                }
                for i in (-ny)...ny where i != 0 {
                    let y = origin.y + CGFloat(i) * step
                    if y > 8 && y < canvas.height - 8 {
                        context.draw(Text("\(Double(-i) * gridStep, specifier: "%.3g")").font(.system(size: 9)).foregroundColor(.secondary), at: CGPoint(x: min(canvas.width - 18, max(18, origin.x + 18)), y: y))
                    }
                }
                context.draw(Text("O").font(.system(size: 10, weight: .medium)).foregroundColor(.secondary), at: CGPoint(x: origin.x + 10, y: origin.y + 10))
                context.draw(Text("x").font(.system(size: 12, weight: .bold)), at: CGPoint(x: canvas.width - 10, y: origin.y - 12))
                context.draw(Text("y").font(.system(size: 12, weight: .bold)), at: CGPoint(x: origin.x + 12, y: 10))

                guard let function = parsed else { return }
                var curve = Path()
                var previous: CGPoint?
                for px in stride(from: CGFloat(0), through: canvas.width, by: 1) {
                    let x = Double((px - origin.x) / unit)
                    guard let y = function.value(x), abs(y) < visibleRange * 20 else {
                        previous = nil
                        continue
                    }
                    let point = CGPoint(x: px, y: origin.y - CGFloat(y) * unit)
                    if point.y.isFinite, point.y > -canvas.height * 2, point.y < canvas.height * 3 {
                        if let previous, abs(point.y - previous.y) < canvas.height * 0.45 {
                            curve.addLine(to: point)
                        } else {
                            curve.move(to: point)
                        }
                        previous = point
                    } else {
                        previous = nil
                    }
                }
                context.stroke(curve, with: .color(.blue), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

                // Draw comparison curves using the same coordinate transform as the active function.
                let comparisonColors: [Color] = [.orange, .green, .purple, .pink, .teal]
                let comparisonList = enabledComparisonExpressions.sorted()
                for (index, comparison) in comparisonList.enumerated() {
                    guard let comparisonFunction = MathExpression(expression: comparison) else { continue }
                    var comparisonPath = Path()
                    var comparisonPrevious: CGPoint?
                    for px in stride(from: CGFloat(0), through: canvas.width, by: 1) {
                        let x = Double((px - origin.x) / unit)
                        guard let y = comparisonFunction.value(x), abs(y) < visibleRange * 20 else {
                            comparisonPrevious = nil
                            continue
                        }
                        let point = CGPoint(x: px, y: origin.y - CGFloat(y) * unit)
                        if point.y.isFinite, point.y > -canvas.height * 2, point.y < canvas.height * 3 {
                            if let previous = comparisonPrevious, abs(point.y - previous.y) < canvas.height * 0.45 {
                                comparisonPath.addLine(to: point)
                            } else {
                                comparisonPath.move(to: point)
                            }
                            comparisonPrevious = point
                        } else {
                            comparisonPrevious = nil
                        }
                    }
                    context.stroke(
                        comparisonPath,
                        with: .color(comparisonColors[index % comparisonColors.count]),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round)
                    )
                }

                if showAnalysis {
                    for root in xIntercepts {
                        let point = CGPoint(x: origin.x + CGFloat(root) * unit, y: origin.y)
                        if point.x >= 0 && point.x <= canvas.width {
                            context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(.red))
                        }
                    }
                    if let y = yIntercept {
                        let point = CGPoint(x: origin.x, y: origin.y - CGFloat(y) * unit)
                        if point.y >= 0 && point.y <= canvas.height {
                            context.fill(Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)), with: .color(.orange))
                        }
                    }
                    if let vertex {
                        let point = CGPoint(x: origin.x + vertex.x * unit, y: origin.y - vertex.y * unit)
                        if point.x >= 0 && point.x <= canvas.width && point.y >= 0 && point.y <= canvas.height {
                            context.fill(Path(ellipseIn: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)), with: .color(.purple))
                        }
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.gray.opacity(0.25), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(MagnificationGesture()
                .onChanged { value in
                    zoom = min(8, max(0.25, zoomAtStart * value))
                }
                .onEnded { _ in zoomAtStart = zoom })
            .simultaneousGesture(DragGesture()
                .onChanged { value in
                    offset = CGSize(width: offsetAtStart.width + value.translation.width, height: offsetAtStart.height + value.translation.height)
                }
                .onEnded { _ in offsetAtStart = offset })
        }
    }

    private var functionPanel: some View {
        Form {
            Section("输入函数") {
                TextField("例如：y = 2x + 1", text: $expression)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($expressionFocused)
                    .submitLabel(.done)
                if let parsed {
                    Label("表达式有效，正在实时绘图", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("解析为 y = f(x)，支持 + − × ÷、括号、幂运算和常见函数。")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Label("表达式无法解析，请检查格式", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("示例：y=2x+1、y=x^2-4、y=1/x、y=sin(x)")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Toggle("显示关键点", isOn: $showAnalysis)
            }
            Section("对比函数") {
                Text("勾选后可同时比较多条曲线，当前输入函数始终以蓝色显示。")
                    .font(.caption).foregroundStyle(.secondary)
                comparisonToggle("y = x", expression: "x")
                comparisonToggle("y = -x", expression: "-x")
                comparisonToggle("y = x² - 4", expression: "x^2 - 4")
                comparisonToggle("y = 2/x", expression: "2/x")
                comparisonToggle("y = |x|", expression: "abs(x)")
            }
            Section("快速示例") {
                exampleButton("一次函数：y = 2x + 1", "y = 2x + 1")
                exampleButton("二次函数：y = x^2 - 4", "y = x^2 - 4")
                exampleButton("反比例函数：y = 2/x", "y = 2/x")
                exampleButton("正比例函数：y = -3x", "y = -3x")
            }
        }
    }

    private var analysisPanel: some View {
        Form {
            Section("当前函数") {
                LabeledContent("表达式", value: expression)
                if let yIntercept {
                    LabeledContent("与 y 轴交点", value: String(format: "(0, %.4g)", yIntercept))
                } else {
                    LabeledContent("与 y 轴交点", value: "不存在或未定义")
                }
                if xIntercepts.isEmpty {
                    LabeledContent("与 x 轴交点", value: "当前范围内未找到")
                } else {
                    LabeledContent("与 x 轴交点", value: xIntercepts.prefix(8).map { String(format: "(%.4g, 0)", $0) }.joined(separator: "、"))
                }
                if let vertex {
                    LabeledContent("二次函数顶点", value: String(format: "(%.4g, %.4g)", Double(vertex.x), Double(vertex.y)))
                } else {
                    LabeledContent("二次函数顶点", value: "未识别为标准二次多项式")
                }
            }
            Section("函数与坐标轴") {
                Text(axisRelationship)
                    .font(.body)
                Text("交点检测采用数值采样与二分逼近，结果用于学习参考；复杂函数可能存在未检测到的根。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var axisRelationship: String {
        guard let function = parsed else { return "请先输入有效的函数表达式。" }
        let y = function.value(0)
        let roots = xIntercepts
        if let y, abs(y) < 1e-8, roots.contains(where: { abs($0) < 1e-4 }) {
            return "图像经过原点 O(0, 0)，同时与 x 轴和 y 轴相交于原点。"
        }
        if roots.isEmpty, y != nil {
            return "在当前显示范围内没有检测到与 x 轴的交点；图像与 y 轴的交点已在上方列出。"
        }
        return "图像与 x 轴有 \(roots.count) 个已检测交点；与 y 轴的交点由 f(0) 决定。"
    }

    private var tablePanel: some View {
        Form {
            Section("函数值表范围") {
                HStack {
                    Text("起始 x")
                    Spacer()
                    TextField("", value: $xStart, format: .number.precision(.fractionLength(0...3)))
                        .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width: 110)
                }
                HStack {
                    Text("结束 x")
                    Spacer()
                    TextField("", value: $xEnd, format: .number.precision(.fractionLength(0...3)))
                        .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width: 110)
                }
                HStack {
                    Text("步长")
                    Spacer()
                    TextField("", value: $xStep, format: .number.precision(.fractionLength(0...3)))
                        .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(width: 110)
                }
                if xStep <= 0 || xEnd < xStart {
                    Text("请确保结束值不小于起始值，且步长大于 0。").foregroundStyle(.orange)
                }
            }
            Section("计算结果") {
                if let function = parsed, xStep > 0, xEnd >= xStart {
                    let count = min(101, Int((xEnd - xStart) / xStep) + 1)
                    ForEach(0..<max(0, count), id: \.self) { index in
                        let x = xStart + Double(index) * xStep
                        HStack {
                            Text("x = \(x, specifier: "%.4g")")
                            Spacer()
                            Text(function.value(x).map { $0.isFinite ? String(format: "%.6g", $0) : "未定义" } ?? "未定义")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    if count == 101 {
                        Text("最多显示 101 行，请调整步长以查看其他范围。").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("请先输入有效函数，并设置正确的范围与步长。")
                }
            }
        }
    }

    private var learningPanel: some View {
        let lessons: [(String, String, String, String)] = [
            ("一次函数", "y = kx + b", "k 决定倾斜方向与变化快慢，b 是图像与 y 轴的交点纵坐标。", "y = 2x + 1"),
            ("反比例函数", "y = k/x", "当 k 不为 0 时，图像通常有两支，且 x 不能等于 0。k 的正负影响图像所在象限。", "y = 2/x"),
            ("二次函数", "y = ax^2 + bx + c", "图像是抛物线。a 决定开口方向，顶点是图像的关键点。", "y = x^2 - 4")
        ]
        return Form {
            Section("初中函数学习") {
                Picker("选择知识点", selection: $selectedLesson) {
                    ForEach(lessons.indices, id: \.self) { index in
                        Text(lessons[index].0).tag(index)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("第一步 · 认识表达式") {
                Text(lessons[selectedLesson].1).font(.title3.weight(.semibold))
                Text(lessons[selectedLesson].2)
            }
            Section("第二步 · 绘制示例") {
                Text(lessons[selectedLesson].3)
                    .font(.system(.body, design: .monospaced))
                Button("在坐标系中查看此示例") {
                    expression = lessons[selectedLesson].3
                }
                .buttonStyle(.borderedProminent)
            }
            Section("第三步 · 观察与思考") {
                Text("观察图像与 x 轴、y 轴的交点，再改变表达式中的系数，比较图像的变化。试着预测变化，再用绘图验证。")
            }
        }
    }

    private func comparisonToggle(_ title: String, expression value: String) -> some View {
        Toggle(title, isOn: Binding(
            get: { enabledComparisonExpressions.contains(value) },
            set: { isEnabled in
                if isEnabled {
                    enabledComparisonExpressions.insert(value)
                } else {
                    enabledComparisonExpressions.remove(value)
                }
            }
        ))
    }

    private func exampleButton(_ title: String, _ value: String) -> some View {
        Button(title) { expression = value }
            .foregroundStyle(.primary)
    }

    private func roots(for function: MathExpression?, in range: ClosedRange<Double>) -> [Double] {
        guard let function else { return [] }
        let samples = 1600
        let step = (range.upperBound - range.lowerBound) / Double(samples)
        var result: [Double] = []
        var previousX = range.lowerBound
        var previousY = function.value(previousX)
        for index in 1...samples {
            let x = range.lowerBound + Double(index) * step
            let y = function.value(x)
            if let a = previousY, let b = y, a.isFinite, b.isFinite {
                if abs(a) < 1e-7 {
                    result.append(previousX)
                } else if a.sign != b.sign {
                    var low = previousX
                    var high = x
                    for _ in 0..<36 {
                        let mid = (low + high) / 2
                        guard let midY = function.value(mid), midY.isFinite else { break }
                        if (midY >= 0) == (a >= 0) { low = mid } else { high = mid }
                    }
                    result.append((low + high) / 2)
                }
            }
            previousX = x
            previousY = y
        }
        return result.filter { $0.isFinite }.reduce(into: [Double]()) { values, root in
            if !values.contains(where: { abs($0 - root) < max(1e-4, step * 2) }) { values.append(root) }
        }
    }

    private func quadraticVertex(_ input: String) -> CGPoint? {
        guard let normalized = MathExpression.normalize(input) else { return nil }
        let compact = normalized.replacingOccurrences(of: " ", with: "")
        // Recognizes ax^2+bx+c and x^2 plus/minus a constant.
        let pattern = #"^([+-]?[0-9]*\.?[0-9]*)?x\^2([+-][0-9]*\.?[0-9]*)?x?([+-][0-9]*\.?[0-9]*)?$"#
        guard compact.range(of: pattern, options: .regularExpression) != nil else { return nil }
        let cleaned = compact.replacingOccurrences(of: "y=", with: "")
        guard let x2Range = cleaned.range(of: "x^2") else { return nil }
        let aText = String(cleaned[..<x2Range.lowerBound])
        let a = aText.isEmpty || aText == "+" ? 1.0 : (aText == "-" ? -1.0 : (Double(aText) ?? .nan))
        let rest = String(cleaned[x2Range.upperBound...])
        var b = 0.0
        var c = 0.0
        if rest.contains("x") {
            let parts = rest.split(separator: "x", omittingEmptySubsequences: false)
            b = parts.first.flatMap { Double($0) } ?? (parts.first == "+" ? 1 : (parts.first == "-" ? -1 : 0))
            c = parts.count > 1 ? (Double(parts[1]) ?? 0) : 0
        } else {
            c = Double(rest) ?? 0
        }
        guard a.isFinite, abs(a) > 1e-12 else { return nil }
        let xv = -b / (2 * a)
        return CGPoint(x: CGFloat(xv), y: CGFloat(a * xv * xv + b * xv + c))
    }
}

private extension Optional where Wrapped == Double {
    var flatMapFinite: Double? {
        guard let value = self, value.isFinite else { return nil }
        return value
    }
}

private struct MathExpression {
    private let root: Node

    init?(expression: String) {
        guard let normalized = Self.normalize(expression) else { return nil }
        var parser = Parser(source: normalized)
        guard let node = parser.parse(), parser.isAtEnd else { return nil }
        root = node
    }

    static func normalize(_ input: String) -> String? {
        var text = input.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "²", with: "^2")
            .replacingOccurrences(of: "³", with: "^3")
        if text.hasPrefix("y=") { text = String(text.dropFirst(2)) }
        return text.isEmpty ? nil : text
    }

    func value(_ x: Double) -> Double? {
        let result = root.evaluate(x)
        return result.isFinite ? result : nil
    }

    private indirect enum Node {
        case number(Double), variable
        case unary(Character, Node)
        case binary(Character, Node, Node)
        case function(String, Node)

        func evaluate(_ x: Double) -> Double {
            switch self {
            case .number(let value): return value
            case .variable: return x
            case .unary(let op, let node): return op == "-" ? -node.evaluate(x) : node.evaluate(x)
            case .binary(let op, let left, let right):
                let a = left.evaluate(x), b = right.evaluate(x)
                switch op {
                case "+": return a + b
                case "-": return a - b
                case "*": return a * b
                case "/": return b == 0 ? .nan : a / b
                case "^": return pow(a, b)
                default: return .nan
                }
            case .function(let name, let node):
                let value = node.evaluate(x)
                switch name {
                case "sin": return sin(value)
                case "cos": return cos(value)
                case "tan": return tan(value)
                case "abs": return abs(value)
                case "sqrt": return value < 0 ? .nan : sqrt(value)
                case "exp": return exp(value)
                case "ln": return value <= 0 ? .nan : log(value)
                case "log": return value <= 0 ? .nan : log10(value)
                default: return .nan
                }
            }
        }
    }

    private struct Parser {
        private let characters: [Character]
        private var index = 0
        var isAtEnd: Bool { index == characters.count }

        init(source: String) { characters = Array(source) }

        mutating func parse() -> Node? { parseAddition() }

        private mutating func parseAddition() -> Node? {
            guard var node = parseMultiplication() else { return nil }
            while let op = peek, op == "+" || op == "-" {
                index += 1
                guard let rhs = parseMultiplication() else { return nil }
                node = .binary(op, node, rhs)
            }
            return node
        }

        private mutating func parseMultiplication() -> Node? {
            guard var node = parsePower() else { return nil }
            while let op = peek, op == "*" || op == "/" {
                index += 1
                guard let rhs = parsePower() else { return nil }
                node = .binary(op, node, rhs)
            }
            // Accept conventional school notation such as 2x, 3(x + 1), and 2sin(x).
            while startsImplicitMultiplication {
                guard let rhs = parsePower() else { return nil }
                node = .binary("*", node, rhs)
            }
            return node
        }

        private var startsImplicitMultiplication: Bool {
            guard let char = peek else { return false }
            return char == "x" || char == "(" || char.isLetter
        }

        private mutating func parsePower() -> Node? {
            guard var node = parseUnary() else { return nil }
            if peek == "^" {
                index += 1
                guard let rhs = parsePower() else { return nil }
                node = .binary("^", node, rhs)
            }
            return node
        }

        private mutating func parseUnary() -> Node? {
            if peek == "+" { index += 1; return parseUnary() }
            if peek == "-" {
                index += 1
                guard let node = parseUnary() else { return nil }
                return .unary("-", node)
            }
            return parsePrimary()
        }

        private mutating func parsePrimary() -> Node? {
            guard let char = peek else { return nil }
            if char == "(" {
                index += 1
                guard let node = parseAddition(), peek == ")" else { return nil }
                index += 1
                return node
            }
            if char.isNumber || char == "." {
                let start = index
                while let c = peek, c.isNumber || c == "." { index += 1 }
                return Double(String(characters[start..<index])).map(Node.number)
            }
            if char.isLetter {
                let start = index
                while let c = peek, c.isLetter { index += 1 }
                let name = String(characters[start..<index])
                if name == "x" { return .variable }
                if name == "pi" { return .number(Double.pi) }
                if name == "e" { return .number(exp(1)) }
                let functions: Set<String> = ["sin", "cos", "tan", "abs", "sqrt", "exp", "ln", "log"]
                guard functions.contains(name), peek == "(" else { return nil }
                index += 1
                guard let argument = parseAddition(), peek == ")" else { return nil }
                index += 1
                return .function(name, argument)
            }
            return nil
        }

        private var peek: Character? { index < characters.count ? characters[index] : nil }
    }
}

#Preview {
    ContentView()
}
