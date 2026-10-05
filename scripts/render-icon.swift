#!/usr/bin/env swift
// Renders the Apple TV icon and Top Shelf images into Snake/Assets.xcassets.
// A tvOS icon is a stack of layers that shift apart when the icon has focus:
// the LCD screen at the back, the snake in the middle and the food in front.
// Usage: swift scripts/render-icon.swift

import AppKit
import ImageIO
import UniformTypeIdentifiers

let lcd: UInt32 = 0xC7F0D8
let ink: UInt32 = 0x43523D

// The artwork is drawn on LCD pixels, 30 of them across the image's height.
// A cell is 4 pixels, a 3x3 block plus a gap, like in the game.
let pixelsTall: CGFloat = 30
// Tail first, heading right toward the food.
let snake = [(0, 2), (1, 2), (1, 1), (1, 0), (2, 0), (3, 0), (4, 0), (4, 1), (4, 2), (5, 2), (6, 2)]
let food = (8, 2)

func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
    green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255,
    alpha: alpha
  )
}

func render(width: CGFloat, height: CGFloat, _ draw: (CGContext) -> Void) -> CGImage {
  let context = CGContext(
    data: nil,
    width: Int(width),
    height: Int(height),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  context.translateBy(x: 0, y: height)
  context.scaleBy(x: 1, y: -1)
  draw(context)
  return context.makeImage()!
}

struct Grid {
  let pixel: CGFloat
  let columns: Int
  let rows: Int
  let originX: CGFloat
  // The pixel where cell (0, 0) starts, so the artwork sits in the middle.
  let artX: Int
  let artY: Int

  init(width: CGFloat, height: CGFloat) {
    pixel = height / pixelsTall
    rows = Int(pixelsTall)
    columns = Int(width / pixel)
    originX = (width - CGFloat(columns) * pixel) / 2
    let cells = (snake + [food])
    let artWidth = 4 * (cells.map(\.0).max()! + 1) - 1
    let artHeight = 4 * (cells.map(\.1).max()! + 1) - 1
    artX = (columns - artWidth) / 2
    artY = (rows - artHeight) / 2
  }

  func fill(_ context: CGContext, _ pixels: [(Int, Int)]) {
    let size = pixel * 0.88
    for (x, y) in pixels {
      context.fill(CGRect(x: originX + CGFloat(x) * pixel, y: CGFloat(y) * pixel, width: size, height: size))
    }
  }

  func cell(_ cell: (Int, Int)) -> (Int, Int) {
    (artX + 4 * cell.0, artY + 4 * cell.1)
  }
}

func drawScreen(_ context: CGContext, _ grid: Grid) {
  context.setFillColor(rgb(lcd))
  context.fill(CGRect(x: 0, y: 0, width: CGFloat(context.width), height: CGFloat(context.height)))
  context.setFillColor(rgb(ink, alpha: 0.08))
  grid.fill(context, (0..<grid.rows).flatMap { y in (0..<grid.columns).map { ($0, y) } })
}

func drawSnake(_ context: CGContext, _ grid: Grid) {
  var pixels: [(Int, Int)] = []
  for (index, segment) in snake.enumerated() {
    let (x, y) = grid.cell(segment)
    pixels += (0..<9).map { (x + $0 % 3, y + $0 / 3) }
    guard index + 1 < snake.count else { continue }
    let next = snake[index + 1]
    let joint = grid.cell((min(segment.0, next.0), min(segment.1, next.1)))
    pixels += (0..<3).map { next.1 == segment.1 ? (joint.0 + 3, joint.1 + $0) : (joint.0 + $0, joint.1 + 3) }
  }
  context.setFillColor(rgb(ink))
  grid.fill(context, pixels)
}

func drawFood(_ context: CGContext, _ grid: Grid) {
  let (x, y) = grid.cell(food)
  context.setFillColor(rgb(ink))
  grid.fill(context, [(x + 1, y), (x, y + 1), (x + 2, y + 1), (x + 1, y + 2)])
}

typealias Layer = (CGContext, Grid) -> Void

func image(width: CGFloat, height: CGFloat, _ layers: [Layer]) -> CGImage {
  let grid = Grid(width: width, height: height)
  return render(width: width, height: height) { context in
    for layer in layers {
      layer(context, grid)
    }
  }
}

func write(_ image: CGImage, to url: URL) {
  let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, image, nil)
  CGImageDestinationFinalize(destination)
}

func writeContents(_ folder: URL, _ body: String? = nil) {
  try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  let info = #"  "info" : { "author" : "xcode", "version" : 1 }"#
  let json = "{\n" + [body, info].compactMap { $0 }.joined(separator: ",\n") + "\n}\n"
  try! json.write(to: folder.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
}

func writeImageSet(_ folder: URL, width: CGFloat, height: CGFloat, scales: [Int], _ layers: [Layer]) {
  try! FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
  var images: [String] = []
  for scale in scales {
    let name = scale == 1 ? "image.png" : "image@\(scale)x.png"
    write(image(width: width * CGFloat(scale), height: height * CGFloat(scale), layers), to: folder.appendingPathComponent(name))
    images.append(#"    { "filename" : "\#(name)", "idiom" : "tv", "scale" : "\#(scale)x" }"#)
  }
  writeContents(folder, "  \"images\" : [\n" + images.joined(separator: ",\n") + "\n  ]")
}

func writeIconStack(_ folder: URL, width: CGFloat, height: CGFloat, scales: [Int]) {
  let layers: [(name: String, draw: Layer)] = [("Front", drawFood), ("Middle", drawSnake), ("Back", drawScreen)]
  for layer in layers {
    let layerFolder = folder.appendingPathComponent("\(layer.name).imagestacklayer")
    writeContents(layerFolder)
    writeImageSet(layerFolder.appendingPathComponent("Content.imageset"), width: width, height: height, scales: scales, [layer.draw])
  }
  let list = layers.map { #"    { "filename" : "\#($0.name).imagestacklayer" }"# }.joined(separator: ",\n")
  writeContents(folder, "  \"layers\" : [\n" + list + "\n  ]")
}

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("Snake/Assets.xcassets")
let brand = assets.appendingPathComponent("AppIcon.brandassets")
let everything: [Layer] = [drawScreen, drawSnake, drawFood]
try? FileManager.default.removeItem(at: assets)
writeContents(assets)
writeIconStack(brand.appendingPathComponent("App Icon.imagestack"), width: 400, height: 240, scales: [1, 2])
writeIconStack(brand.appendingPathComponent("App Icon - App Store.imagestack"), width: 1280, height: 768, scales: [1])
writeImageSet(brand.appendingPathComponent("Top Shelf Image.imageset"), width: 1920, height: 720, scales: [1, 2], everything)
writeImageSet(brand.appendingPathComponent("Top Shelf Image Wide.imageset"), width: 2320, height: 720, scales: [1, 2], everything)
writeContents(brand, """
  "assets" : [
    { "filename" : "App Icon - App Store.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "1280x768" },
    { "filename" : "App Icon.imagestack", "idiom" : "tv", "role" : "primary-app-icon", "size" : "400x240" },
    { "filename" : "Top Shelf Image Wide.imageset", "idiom" : "tv", "role" : "top-shelf-image-wide", "size" : "2320x720" },
    { "filename" : "Top Shelf Image.imageset", "idiom" : "tv", "role" : "top-shelf-image", "size" : "1920x720" }
  ]
""")
print("Wrote \(assets.path)")

// A flattened preview of the focused icon, to check the artwork.
let preview = root.appendingPathComponent("build/icon-preview.png")
try! FileManager.default.createDirectory(at: preview.deletingLastPathComponent(), withIntermediateDirectories: true)
write(image(width: 800, height: 480, everything), to: preview)
print("Wrote \(preview.path)")
