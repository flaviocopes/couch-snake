#!/usr/bin/env swift
// Renders the README banner, docs/banner.png, at 2x: the icon, the name, a tagline and
// feature chips on the left, the game on a TV on the right.
// The icon is stacked from the layers scripts/render-icon.swift writes, and the TV shows
// docs/screenshot.png, made by scripts/screenshot.sh.
// Usage: swift scripts/render-banner.swift

import AppKit
import SwiftUI

let name = "Snake"
let tagline = "The classic phone game,\nfull screen on your Apple TV."
let chips = ["Swipe to steer", "LCD pixels", "Through the walls"]
let size = CGSize(width: 1280, height: 560)
let tvWidth: CGFloat = 620

// The icon's ink color, deeper, with a glow in its LCD green.
let backgroundTop = Color(hex: 0x3A4834)
let backgroundBottom = Color(hex: 0x161D14)
let glow = Color(hex: 0xC7F0D8)
let muted = Color.white.opacity(0.72)

let root = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let iconStack = root.appending(path: "Snake/Assets.xcassets/AppIcon.brandassets/App Icon.imagestack")
let screenshot = root.appending(path: "docs/screenshot.png")
let output = root.appending(path: "docs/banner.png")

extension Color {
  init(hex: UInt32) {
    self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }
}

func iconLayer(_ name: String) -> NSImage {
  NSImage(contentsOf: iconStack.appending(path: "\(name).imagestacklayer/Content.imageset/image@2x.png"))!
}

/// A faint grid of LCD pixels behind everything.
struct Pixels: View {
  var body: some View {
    Canvas { context, canvasSize in
      let pixel: CGFloat = 14
      var path = Path()
      for y in stride(from: 0, to: canvasSize.height, by: pixel) {
        for x in stride(from: 0, to: canvasSize.width, by: pixel) {
          path.addRect(CGRect(x: x, y: y, width: pixel - 2, height: pixel - 2))
        }
      }
      context.fill(path, with: .color(.white.opacity(0.025)))
    }
  }
}

struct Banner: View {
  let layers: [NSImage]
  let game: NSImage

  var body: some View {
    ZStack(alignment: .topLeading) {
      LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
      RadialGradient(colors: [glow.opacity(0.18), glow.opacity(0)], center: UnitPoint(x: 0.16, y: 0.3), startRadius: 0, endRadius: 420)
      Pixels()

      Image(nsImage: game)
        .resizable()
        .interpolation(.high)
        .frame(width: tvWidth, height: tvWidth * 9 / 16)
        .clipShape(.rect(cornerRadius: 4))
        .padding(12)
        .background(Color(hex: 0x0B0B0B), in: .rect(cornerRadius: 16))
        .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
        .offset(x: 590, y: (size.height - tvWidth * 9 / 16 - 24) / 2)

      VStack(alignment: .leading, spacing: 0) {
        ZStack {
          ForEach(layers.indices, id: \.self) { index in
            Image(nsImage: layers[index])
              .resizable()
              .interpolation(.high)
          }
        }
        .frame(width: 200, height: 120)
        .clipShape(.rect(cornerRadius: 12))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
        Text(name)
          .font(.system(size: 76, weight: .bold))
          .tracking(-1.8)
          .foregroundStyle(.white)
          .padding(.top, 26)
        Text(tagline)
          .font(.system(size: 27, weight: .regular))
          .lineSpacing(4)
          .foregroundStyle(muted)
          .padding(.top, 8)
        HStack(spacing: 10) {
          ForEach(chips, id: \.self) { chip in
            Text(chip)
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.white.opacity(0.9))
              .padding(.horizontal, 14)
              .padding(.vertical, 7)
              .background(.white.opacity(0.1), in: .capsule)
              .overlay(Capsule().strokeBorder(.white.opacity(0.18)))
          }
        }
        .padding(.top, 26)
      }
      .offset(x: 84, y: 78)
    }
    .frame(width: size.width, height: size.height)
    .clipShape(.rect(cornerRadius: 28))
  }
}

MainActor.assumeIsolated {
  let banner = Banner(layers: ["Back", "Middle", "Front"].map(iconLayer), game: NSImage(contentsOf: screenshot)!)
  let renderer = ImageRenderer(content: banner)
  renderer.scale = 2
  // ImageRenderer produces 16 bits per channel. Redraw at 8 bits for a small PNG.
  let image = renderer.cgImage!
  let context = CGContext(
    data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  )!
  context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
  let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
  try! rep.representation(using: .png, properties: [:])!.write(to: output)
  print("Wrote \(output.path)")
}
