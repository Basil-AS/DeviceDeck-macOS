import AppKit
import Foundation

// Create a neutral DeviceDeck headphones icon, independent of any vendor app.
// Usage: xcrun swift make-icon.swift <iconset-directory> [--export <review-directory>]
let args = CommandLine.arguments
precondition(args.count >= 2, "Expected an iconset output directory")
let output = URL(fileURLWithPath:args[1],isDirectory:true)
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let symbolName = "headphones"
guard let original = NSImage(systemSymbolName:symbolName,accessibilityDescription:"DeviceDeck") else {
    fatalError("The system headphones symbol is unavailable")
}
let configuration = NSImage.SymbolConfiguration(pointSize:512,weight:.regular)
    .applying(NSImage.SymbolConfiguration(paletteColors:[.white]))
guard let symbol=original.withSymbolConfiguration(configuration) else { fatalError("Cannot configure menu bar asset") }
symbol.isTemplate=false
func bitmap(_ size:Int, foregroundOnly:Bool=false, backgroundOnly:Bool=false) -> NSBitmapImageRep {
    let rep=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:size*4,bitsPerPixel:32)!
    NSGraphicsContext.saveGraphicsState()
    let context=NSGraphicsContext(bitmapImageRep:rep)!
    NSGraphicsContext.current=context
    context.imageInterpolation = .high
    context.cgContext.clear(CGRect(x:0,y:0,width:size,height:size))
    let s=CGFloat(size)
    if !foregroundOnly {
        let box=NSRect(x:s*0.07,y:s*0.07,width:s*0.86,height:s*0.86)
        let path=NSBezierPath(roundedRect:box,xRadius:s*0.20,yRadius:s*0.20)
        NSColor(calibratedRed:0.063,green:0.082,blue:0.133,alpha:1).setFill()
        path.fill()
    }
    if !backgroundOnly {
        let ratio=symbol.size.width/symbol.size.height
        let width=s*0.57
        let height=width/ratio
        let frame=NSRect(x:(s-width)/2,y:(s-height)/2,width:width,height:height)
        symbol.draw(in:frame,from:.zero,operation:.sourceOver,fraction:1,respectFlipped:false,hints:[.interpolation:NSImageInterpolation.high])
    }
    context.cgContext.flush()
    NSGraphicsContext.restoreGraphicsState()
    return rep.retagging(with:.sRGB)!
}
func save(_ rep:NSBitmapImageRep,_ url:URL) throws {
    guard let png=rep.representation(using:.png,properties:[:]) else { fatalError("PNG encoding failed") }
    try png.write(to:url,options:.atomic)
}
for base in [16,32,128,256,512] {
    for scale in [1,2] {
        let name="icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try save(bitmap(base*scale),output.appendingPathComponent(name))
    }
}
if let i=args.firstIndex(of:"--export"), i+1<args.count {
    let review=URL(fileURLWithPath:args[i+1],isDirectory:true)
    try FileManager.default.createDirectory(at:review,withIntermediateDirectories:true)
    try save(bitmap(1024),review.appendingPathComponent("DeviceDeck-1024.png"))
    try save(bitmap(512),review.appendingPathComponent("DeviceDeck-512.png"))
    try save(bitmap(1024,foregroundOnly:true),review.appendingPathComponent("menu-bar-asset-1024.png"))
    try save(bitmap(1024,backgroundOnly:true),review.appendingPathComponent("original-background-1024.png"))
    try "{\n  \"source\": \"macOS SF Symbol headphones\",\n  \"redrawn\": false,\n  \"symbolAspectRatio\": \(symbol.size.width/symbol.size.height),\n  \"foregroundCanvasWidthFraction\": 0.57,\n  \"background\": \"DeviceDeck midnight slate #101522\"\n}\n".write(to:review.appendingPathComponent("source.json"),atomically:true,encoding:.utf8)
}
print("Generated 10 DeviceDeck icon representations using \(symbolName), aspect \(symbol.size.width/symbol.size.height)")
