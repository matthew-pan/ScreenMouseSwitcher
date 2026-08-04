import AppKit

// 生成一枚 App 图标 PNG（一只电脑鼠标）。
// 用法：swift scripts/make_icon.swift <输出路径.png>
let sideLength: CGFloat = 1024
let image = NSImage(size: NSSize(width: sideLength, height: sideLength))
image.lockFocus()

// 圆角蓝色底。
let background = NSBezierPath(
    roundedRect: NSRect(x: 80, y: 80, width: sideLength - 160, height: sideLength - 160),
    xRadius: 180, yRadius: 180
)
NSColor(calibratedRed: 0.16, green: 0.50, blue: 0.95, alpha: 1).setFill()
background.fill()

// 鼠标机身（白色圆角，上窄下宽的胶囊形）。
let bodyRect = NSRect(x: 342, y: 210, width: 340, height: 604)
let body = NSBezierPath(roundedRect: bodyRect, xRadius: 170, yRadius: 200)
NSColor.white.setFill()
body.fill()

// 机身描边。
NSColor(calibratedRed: 0.12, green: 0.34, blue: 0.72, alpha: 1).setStroke()
body.lineWidth = 10
body.stroke()

let accent = NSColor(calibratedRed: 0.16, green: 0.50, blue: 0.95, alpha: 1)

// 顶部左右按键分隔线。
accent.setStroke()
let split = NSBezierPath()
split.move(to: NSPoint(x: 512, y: 812))
split.line(to: NSPoint(x: 512, y: 600))
split.lineWidth = 14
split.lineCapStyle = .round
split.stroke()

// 滚轮。
accent.setFill()
NSBezierPath(roundedRect: NSRect(x: 493, y: 640, width: 38, height: 96),
             xRadius: 19, yRadius: 19).fill()

image.unlockFocus()

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
if let tiff = image.tiffRepresentation,
   let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    do {
        try png.write(to: URL(fileURLWithPath: outputPath))
    } catch {
        FileHandle.standardError.write("写入图标失败: \(error)\n".data(using: .utf8)!)
        exit(1)
    }
} else {
    FileHandle.standardError.write("生成图标数据失败\n".data(using: .utf8)!)
    exit(1)
}
