import SwiftUI

struct GameView: View {
  @State private var game = SnakeGame()
  @State private var snakeHidden = false
  @State private var sounds = Sounds()
  @State private var players = Players()
  @State private var showsPlayers = false
  /// The screen color of the current game. It starts on the last one, so the first game ever
  /// gets the first color, the LCD green.
  @AppStorage("screen") private var screen = Color.screens.count - 1
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
    .background(screenColor)
    .animation(.easeInOut(duration: 0.5), value: screen)
    .focusable(interactions: .activate)
    .focusEffectDisabled()
    .onMoveCommand(perform: turn)
    .onTapGesture(perform: click)
    .onAppear(perform: nextScreen)
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
    .onChange(of: game.score) { oldScore, newScore in
      if newScore > oldScore {
        sounds.playFood()
      }
      players.record(newScore)
    }
    .fullScreenCover(isPresented: $showsPlayers) {
      PlayersView(players: players, background: screenColor, choose: choose)
    }
  }

  @ViewBuilder
  private var message: some View {
    switch game.state {
    case .ready: MessageBox(title: "COUCH SNAKE", detail: "Swipe to start", hint: "Play/Pause for players", background: screenColor)
    case .paused: MessageBox(title: "PAUSED", detail: "Click to continue", background: screenColor)
    case .over: MessageBox(title: "GAME OVER", detail: "Click to play again", hint: "Play/Pause for players", background: screenColor)
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
    let turned: Bool
    switch direction {
    case .up: turned = game.turn(.up)
    case .down: turned = game.turn(.down)
    case .left: turned = game.turn(.left)
    case .right: turned = game.turn(.right)
    @unknown default: turned = false
    }
    if turned {
      sounds.playTurn()
    }
  }

  private var screenColor: Color {
    Color.screens[screen % Color.screens.count]
  }

  /// Every new game gets the next screen color.
  private func nextScreen() {
    screen = (screen + 1) % Color.screens.count
  }

  private func click() {
    if game.state == .over {
      game = SnakeGame()
      nextScreen()
    } else {
      game.resume()
    }
  }

  /// A new player after a game over gets a fresh board.
  private func choose(_ player: Player) {
    players.select(player)
    showsPlayers = false
    if game.state == .over {
      game = SnakeGame()
      nextScreen()
    }
  }

  /// Play/Pause pauses and resumes a game. Between games it opens the players screen.
  private func playPause() {
    switch game.state {
    case .playing: game.pause()
    case .paused: game.resume()
    case .ready, .over: showsPlayers = true
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
    let hi = "HI " + String(format: "%04d", players.current.best)
    write(hi, x: layout.columns - hi.count * 4 + 1)
    let name = players.current.name
    write(name, x: (layout.columns - name.count * 4 + 1) / 2)

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
  var hint: String?
  let background: Color

  var body: some View {
    VStack(spacing: 20) {
      Text(title)
        .font(.system(size: 80, weight: .black, design: .monospaced))
      Text(detail)
        .font(.system(size: 38, weight: .bold, design: .monospaced))
      if let hint {
        Text(hint)
          .font(.system(size: 28, weight: .semibold, design: .monospaced))
          .opacity(0.7)
      }
    }
    .padding(.horizontal, 70)
    .padding(.vertical, 44)
    .background(background)
    .border(Color.ink, width: 9)
  }
}

/// A 3x5 pixel font, read left to right, top to bottom. Player names use the letters,
/// so `Players.name(from:)` keeps names to what's here.
private let glyphs: [Character: String] = [
  " ": "000000000000000",
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
  "A": "010101111101101",
  "B": "110101110101110",
  "C": "011100100100011",
  "D": "110101101101110",
  "E": "111100110100111",
  "F": "111100110100100",
  "G": "011100101101011",
  "H": "101101111101101",
  "I": "111010010010111",
  "J": "001001001101010",
  "K": "101101110101101",
  "L": "100100100100111",
  "M": "101111111101101",
  "N": "110101101101101",
  "O": "010101101101010",
  "P": "110101110100100",
  "Q": "010101101110011",
  "R": "110101110101101",
  "S": "011100010001110",
  "T": "111010010010010",
  "U": "101101101101111",
  "V": "101101101101010",
  "W": "101101111111101",
  "X": "101101010101101",
  "Y": "101101010010010",
  "Z": "111001010100111",
]

extension Color {
  // Same colors as the icon in scripts/render-icon.swift.
  static let lcd = Color(hex: 0xC7F0D8)
  static let ink = Color(hex: 0x43523D)

  /// The pastel screen colors, one per game in this order. Neighbors are far apart in hue,
  /// so every new game looks different. They all need to stay pale for the ink to read.
  static let screens: [Color] = [
    .lcd, Color(hex: 0xF8F1C0), Color(hex: 0xE2D9F3), Color(hex: 0xF9DCC4),
    Color(hex: 0xCFE5F5), Color(hex: 0xF7D4E0), Color(hex: 0xDCEEC3), Color(hex: 0xD5DCF5),
    Color(hex: 0xEEE4CC), Color(hex: 0xC9EEEA), Color(hex: 0xEBD6EE), Color(hex: 0xF8D2C8),
  ]

  init(hex: UInt32) {
    self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
  }
}
