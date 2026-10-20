import SwiftUI

struct ContentView: View {
    @State private var scale: CGFloat = 1
    @State private var savedScale: CGFloat = 1
    @State private var pan = CGSize.zero
    @State private var savedPan = CGSize.zero
    @State private var showSine = true
    @State private var showCosine = true
    @State private var showQuadratic = true
    @State private var showLinear = false
    @State private var showAbsolute = false
    @State private var showExponential = false
    @State private var customExpression = "sin(x)"
    @State private var showCustom = false

    private let baseRange: CGFloat = 10
    private var range: CGFloat { baseRange / max(0.25, min(scale, 8)) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                graph
                    .frame(minHeight: 320)
                    .padding(.horizontal, 12)
                    .padding(.top, 12)

                HStack {
                    Label("范围 ±\(range, specifier: "%.1f")", systemImage: "arrow.left.and.right")
                    Spacer()
                    Button {
                        withAnimation(.spring) {
                            scale = 1
                            savedScale = 1
                            pan = .zero
                            savedPan = .zero
                        }
                    } label: {
                        Label("重置视图", systemImage: "arrow.counterclockwise")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)

                Form {
                    Section("内置函数") {
                        functionToggle("正弦函数", formula: "y = sin(x)", color: .blue, isOn: $showSine)
                        functionToggle("余弦函数", formula: "y = cos(x)", color: .orange, isOn: $showCosine)
                        functionToggle("二次函数", formula: "y = x² / 4", color: .purple, isOn: $showQuadratic)
                        functionToggle("一次函数", formula: "y = x", color: .green, isOn: $showLinear)
                        functionToggle("绝对值函数", formula: "y = |x| / 2", color: .pink, isOn: $showAbsolute)
                        functionToggle("指数函数", formula: "y = eˣ / 10", color: .red, isOn: $showExponential)
                    }
                    Section("自定义函数") {
                        TextField("例如：sin(x)", text: $customExpression)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Toggle("绘制自定义函数", isOn: $showCustom)
                        Text("支持：x、x^2、sin(x)、cos(x)、tan(x)、abs(x)、sqrt(abs(x))、exp(x)、ln(abs(x))。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(minHeight: 290)
            }
            .navigationTitle("函数绘图")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var graph: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2 + pan.width, y: canvasSize.height / 2 + pan.height)
                let pixelsPerUnit = min(canvasSize.width, canvasSize.height) / (2 * range)

                // Grid
                var grid = Path()
                let step = gridStep(for: range)
                let left = Int(floor((-center.x) / (pixelsPerUnit * step))) - 1
                let right = Int(ceil((canvasSize.width - center.x) / (pixelsPerUnit * step))) + 1
                for i in left...right {
                    let x = center.x + CGFloat(i) * step * pixelsPerUnit
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: canvasSize.height))
                }
                let top = Int(floor((center.y - canvasSize.height) / (pixelsPerUnit * step))) - 1
                let bottom = Int(ceil(center.y / (pixelsPerUnit * step))) + 1
                for i in top...bottom {
                    let y = center.y - CGFloat(i) * step * pixelsPerUnit
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: canvasSize.width, y: y))
                }
                context.stroke(grid, with: .color(.gray.opacity(0.18)), lineWidth: 0.7)

                // Axes
                var axes = Path()
                axes.move(to: CGPoint(x: 0, y: center.y))
                axes.addLine(to: CGPoint(x: canvasSize.width, y: center.y))
                axes.move(to: CGPoint(x: center.x, y: 0))
                axes.addLine(to: CGPoint(x: center.x, y: canvasSize.height))
                context.stroke(axes, with: .color(.primary.opacity(0.75)), lineWidth: 1.4)

                // Tick labels
                for i in left...right where i != 0 {
                    let x = center.x + CGFloat(i) * step * pixelsPerUnit
                    let label = Text("\(CGFloat(i) * step, specifier: "%.3g")").font(.system(size: 9)).foregroundColor(.secondary)
                    context.draw(label, at: CGPoint(x: x + 10, y: center.y + 10))
                }
                for i in top...bottom where i != 0 {
                    let y = center.y - CGFloat(i) * step * pixelsPerUnit
                    let label = Text("\(CGFloat(i) * step, specifier: "%.3g")").font(.system(size: 9)).foregroundColor(.secondary)
                    context.draw(label, at: CGPoint(x: center.x + 15, y: y - 8))
                }
                context.draw(Text("x").font(.system(size: 12, weight: .bold)), at: CGPoint(x: canvasSize.width - 12, y: center.y - 12))
                context.draw(Text("y").font(.system(size: 12, weight: .bold)), at: CGPoint(x: center.x + 12, y: 12))

                func drawCurve(_ color: Color, _ function: (Double) -> Double) {
                    var path = Path()
                    var started = false
                    for pixelX in stride(from: CGFloat(0), through: canvasSize.width, by: 1.5) {
                        let x = Double((pixelX - center.x) / pixelsPerUnit)
                        let y = function(x)
                        let pixelY = center.y - CGFloat(y) * pixelsPerUnit
                        if y.isFinite && abs(y) < Double(range * 8) && pixelY.isFinite {
                            let point = CGPoint(x: pixelX, y: pixelY)
                            if started && abs(point.y - (path.currentPoint?.y ?? point.y)) < canvasSize.height * 0.6 {
                                path.addLine(to: point)
                            } else {
                                path.move(to: point)
                            }
                            started = true
                        } else {
                            started = false
                        }
                    }
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }

                if showSine { drawCurve(.blue) { sin($0) } }
                if showCosine { drawCurve(.orange) { cos($0) } }
                if showQuadratic { drawCurve(.purple) { $0 * $0 / 4 } }
                if showLinear { drawCurve(.green) { $0 } }
                if showAbsolute { drawCurve(.pink) { abs($0) / 2 } }
                if showExponential { drawCurve(.red) { exp($0) / 10 } }
                if showCustom, let evaluator = ExpressionEvaluator(expression: customExpression) {
                    drawCurve(.teal) { evaluator.value(at: $0) }
                }
            }
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(.gray.opacity(0.25), lineWidth: 1))
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(8, max(0.25, savedScale * value))
                    }
                    .onEnded { _ in savedScale = scale }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in pan = CGSize(width: savedPan.width + value.translation.width, height: savedPan.height + value.translation.height) }
                    .onEnded { _ in savedPan = pan }
            )
        }
    }

    private func gridStep(for range: CGFloat) -> CGFloat {
        if range > 20 { return 5 }
        if range > 8 { return 2 }
        if range > 3 { return 1 }
        if range > 1.5 { return 0.5 }
        return 0.25
    }

    private func functionToggle(_ title: String, formula: String, color: Color, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 25)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(formula).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ExpressionEvaluator {
    let expression: String

    init?(expression: String) {
        let normalized = expression.lowercased().replacingOccurrences(of: " ", with: "")
        guard !normalized.isEmpty,
              normalized.allSatisfy({ $0.isNumber || "x+-*/^().sincotaqbrtlephg".contains($0) }) else { return nil }
        self.expression = normalized
    }

    func value(at x: Double) -> Double {
        evaluate(expression, x: x)
    }

    private func evaluate(_ text: String, x: Double) -> Double {
        if text == "x" { return x }
        if text == "pi" { return Double.pi }
        if text == "e" { return M_E }
        if let number = Double(text) { return number }
        for op in ["+", "-"] {
            if let index = splitIndex(text, operators: [op]) {
                let a = evaluate(String(text[..<index]), x: x)
                let b = evaluate(String(text[text.index(after: index)...]), x: x)
                return op == "+" ? a + b : a - b
            }
        }
        for op in ["*", "/"] {
            if let index = splitIndex(text, operators: [op]) {
                let a = evaluate(String(text[..<index]), x: x)
                let b = evaluate(String(text[text.index(after: index)...]), x: x)
                return op == "*" ? a * b : (b == 0 ? .nan : a / b)
            }
        }
        if let index = splitIndex(text, operators: ["^"]) {
            return pow(evaluate(String(text[..<index]), x: x), evaluate(String(text[text.index(after: index)...]), x: x))
        }
        if text.hasPrefix("-") { return -evaluate(String(text.dropFirst()), x: x) }
        if text.hasPrefix("sin("), text.hasSuffix(")") { return sin(evaluate(String(text.dropFirst(4).dropLast()), x: x)) }
        if text.hasPrefix("cos("), text.hasSuffix(")") { return cos(evaluate(String(text.dropFirst(4).dropLast()), x: x)) }
        if text.hasPrefix("tan("), text.hasSuffix(")") { return tan(evaluate(String(text.dropFirst(4).dropLast()), x: x)) }
        if text.hasPrefix("abs("), text.hasSuffix(")") { return abs(evaluate(String(text.dropFirst(4).dropLast()), x: x)) }
        if text.hasPrefix("sqrt("), text.hasSuffix(")") { return sqrt(abs(evaluate(String(text.dropFirst(5).dropLast()), x: x))) }
        if text.hasPrefix("exp("), text.hasSuffix(")") { return exp(evaluate(String(text.dropFirst(4).dropLast()), x: x)) }
        if text.hasPrefix("ln("), text.hasSuffix(")") { return log(abs(evaluate(String(text.dropFirst(3).dropLast()), x: x))) }
        return .nan
    }

    private func splitIndex(_ text: String, operators: [Character]) -> String.Index? {
        var depth = 0
        for index in text.indices.reversed() {
            let char = text[index]
            if char == ")" { depth += 1 }
            else if char == "(" { depth -= 1 }
            else if depth == 0 && operators.contains(char) && index != text.startIndex {
                let previous = text[text.index(before: index)]
                if (char == "+" || char == "-") && "+-*/^(".contains(previous) { continue }
                return index
            }
        }
        return nil
    }
}

#Preview {
    ContentView()
}
