import SwiftUI

struct GameView: View {
  @State private var game = SnakeGame()
  @State private var snakeHidden = false
  @AppStorage("best") private var best = 0
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { proxy in
      let layout = LCDLayout(size: proxy.size, columns: game.columns, rows: game.rows)
      ZStack {
        UnlitPixels(layout: layout)
        Canvas { context, _ in
          context.fill(litPixels(layout), with: .color(.ink))
        }
        message
          .position(layout.boardCenter)
      }
    }
    .foregroundStyle(Color.ink)
    .background(Color.lcd)
    .focusable(interactions: .activate)
    .focusEffectDisabled()
    .onMoveCommand(perform: turn)
    .onTapGesture(perform: click)
    .onPlayPauseCommand(perform: playPause)
    .onExitCommand(perform: exitAction)
    .task(id: game.state) {
      switch game.state {
      case .playing: await play()
      case .over: await blink()
      default: break
      }
    }
    .onChange(of: scenePhase) {
      if scenePhase != .active {
        game.pause()
      }
    }
    .onChange(of: game.score) {
      best = max(best, game.score)
    }
  }

  @ViewBuilder
  private var message: some View {
    switch game.state {
    case .ready: MessageBox(title: "SNAKE", detail: "Swipe to start")
    case .paused: MessageBox(title: "PAUSED", detail: "Click to continue")
    case .over: MessageBox(title: "GAME OVER", detail: "Click to play again")
    case .playing: EmptyView()
    }
  }

  private func play() async {
    while game.state == .playing {
      do {
        try await Task.sleep(for: game.interval)
      } catch {
        return
      }
      game.step()
    }
  }

  private func blink() async {
    defer { snakeHidden = false }
    for _ in 0..<6 {
      do {
        try await Task.sleep(for: .milliseconds(250))
      } catch {
        return
      }
      snakeHidden.toggle()
    }
  }

  private func turn(_ direction: MoveCommandDirection) {
    switch direction {
    case .up: game.turn(.up)
    case .down: game.turn(.down)
    case .left: game.turn(.left)
    case .right: game.turn(.right)
    @unknown default: break
    }
  }

  private func click() {
    if game.state == .over {
      game = SnakeGame()
    } else {
      game.resume()
    }
  }

  private func playPause() {
    if game.state == .playing {
      game.pause()
    } else {
      game.resume()
    }
  }

  /// The Menu button pauses a running game. Otherwise it goes back to the Home screen, as tvOS expects.
  private var exitAction: (() -> Void)? {
    guard game.state == .playing else { return nil }
    return { game.pause() }
  }

  private func litPixels(_ layout: LCDLayout) -> Path {
    var path = Path()
    func light(_ x: Int, _ y: Int) {
      path.addRect(layout.rect(x, y))
    }
    func write(_ text: String, x: Int) {
      for (index, character) in text.enumerated() {
        for (bit, value) in (glyphs[character] ?? "").enumerated() where value == "1" {
          light(x + index * 4 + bit % 3, bit / 3)
        }
      }
    }

    write(String(format: "%04d", game.score), x: 0)
    let hi = "HI " + String(format: "%04d", best)
    write(hi, x: layout.columns - hi.count * 4 + 1)

    let top = LCDLayout.headerHeight
    for x in 0..<layout.columns {
      light(x, top)
      light(x, layout.rows - 1)
    }
    for y in top + 1..<layout.rows - 1 {
      light(0, y)
      light(layout.columns - 1, y)
    }

    let food = layout.origin(of: game.food)
    for (dx, dy) in [(1, 0), (0, 1), (2, 1), (1, 2)] {
      light(food.x + dx, food.y + dy)
    }

    guard !snakeHidden else { return path }
    for (index, cell) in game.snake.enumerated() {
      let block = layout.origin(of: cell)
      for dy in 0..<3 {
        for dx in 0..<3 {
          light(block.x + dx, block.y + dy)
        }
      }
      // Segments are 3x3 blocks, joined by a line of pixels to the next one.
      guard index + 1 < game.snake.count else { continue }
      let next = game.snake[index + 1]
      if let (cell, horizontal) = joint(cell, next) {
        let block = layout.origin(of: cell)
        for offset in 0..<3 {
          if horizontal {
            light(block.x + 3, block.y + offset)
          } else {
            light(block.x + offset, block.y + 3)
          }
        }
      }
    }
    return path
  }

  /// The cell whose right (horizontal) or bottom edge touches the other one.
  /// Segments on opposite edges of the board, where the snake wraps around, have no joint.
  private func joint(_ a: Cell, _ b: Cell) -> (Cell, Bool)? {
    if a.y == b.y && abs(a.x - b.x) == 1 {
      return (a.x < b.x ? a : b, true)
    }
    if a.x == b.x && abs(a.y - b.y) == 1 {
      return (a.y < b.y ? a : b, false)
    }
    return nil
  }
}

/// The screen as a grid of LCD pixels: the score on top, then the framed board.
/// A board cell is 4 pixels wide, a 3x3 block plus a gap.
struct LCDLayout: Equatable {
  static let headerHeight = 7

  let columns: Int
  let rows: Int
  let pixel: CGFloat
  let origin: CGPoint

  init(size: CGSize, columns: Int, rows: Int) {
    self.columns = 4 * columns + 3
    self.rows = Self.headerHeight + 4 * rows + 3
    pixel = max(1, floor(min(size.width / CGFloat(self.columns), size.height / CGFloat(self.rows))))
    origin = CGPoint(
      x: (size.width - CGFloat(self.columns) * pixel) / 2,
      y: (size.height - CGFloat(self.rows) * pixel) / 2
    )
  }

  func rect(_ x: Int, _ y: Int) -> CGRect {
    let size = pixel * 0.88
    return CGRect(x: origin.x + CGFloat(x) * pixel, y: origin.y + CGFloat(y) * pixel, width: size, height: size)
  }

  /// The top-left pixel of a board cell, inside the frame and its 1 pixel gap.
  func origin(of cell: Cell) -> (x: Int, y: Int) {
    (2 + 4 * cell.x, Self.headerHeight + 2 + 4 * cell.y)
  }

  var boardCenter: CGPoint {
    CGPoint(
      x: origin.x + CGFloat(columns) * pixel / 2,
      y: origin.y + (CGFloat(Self.headerHeight) + CGFloat(rows - Self.headerHeight) / 2) * pixel
    )
  }
}

/// The faint grid of pixels that are off. It only redraws when the layout changes.
struct UnlitPixels: View {
  let layout: LCDLayout

  var body: some View {
    Canvas { context, _ in
      var path = Path()
      for y in 0..<layout.rows {
        for x in 0..<layout.columns {
          path.addRect(layout.rect(x, y))
        }
      }
      context.fill(path, with: .color(.ink.opacity(0.06)))
    }
  }
}

struct MessageBox: View {
  let title: String
  let detail: String

  var body: some View {
    VStack(spacing: 20) {
      Text(title)
        .font(.system(size: 80, weight: .black, design: .monospaced))
      Text(detail)
        .font(.system(size: 38, weight: .bold, design: .monospaced))
    }
    .padding(.horizontal, 70)
    .padding(.vertical, 44)
    .background(Color.lcd)
    .border(Color.ink, width: 9)
  }
}

/// A 3x5 pixel font, read left to right, top to bottom.
private let glyphs: [Character: String] = [
  "0": "111101101101111",
  "1": "010110010010111",
  "2": "111001111100111",
  "3": "111001111001111",
  "4": "101101111001001",
  "5": "111100111001111",
  "6": "111100111101111",
  "7": "111001001001001",
  "8": "111101111101111",
  "9": "111101111001111",
  "H": "101101111101101",
  "I": "111010010010111",
]

// Same colors as the icon in scripts/render-icon.swift.
extension Color {
  static let lcd = Color(red: 0.780, green: 0.941, blue: 0.847)
  static let ink = Color(red: 0.263, green: 0.322, blue: 0.239)
}
