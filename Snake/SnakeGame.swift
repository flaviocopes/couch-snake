struct Cell: Hashable {
  var x: Int
  var y: Int
}

enum Direction {
  case up, down, left, right

  var opposite: Direction {
    switch self {
    case .up: .down
    case .down: .up
    case .left: .right
    case .right: .left
    }
  }
}

/// The rules of the game, with no UI. The snake wraps around the edges.
struct SnakeGame {
  enum State {
    case ready, playing, paused, over
  }

  let columns: Int
  let rows: Int
  /// Head first.
  var snake: [Cell]
  var food: Cell
  private(set) var state = State.ready
  private var direction = Direction.right
  private var turns: [Direction] = []

  init(columns: Int = 30, rows: Int = 15) {
    self.columns = columns
    self.rows = rows
    snake = (0..<3).map { Cell(x: columns / 4 - $0, y: rows / 2) }
    food = Cell(x: 0, y: 0)
    food = freeCells.randomElement()!
  }

  var score: Int { snake.count - 3 }

  /// The snake speeds up as it grows.
  var interval: Duration { .milliseconds(max(60, 150 - 3 * score)) }

  mutating func resume() {
    if state == .ready || state == .paused {
      state = .playing
    }
  }

  mutating func pause() {
    if state == .playing {
      state = .paused
    }
  }

  /// Queues a turn for the next steps, so two quick swipes make a U-turn.
  mutating func turn(_ newDirection: Direction) {
    if state == .ready {
      state = .playing
    }
    guard state == .playing, turns.count < 3 else { return }
    let last = turns.last ?? direction
    if newDirection != last && newDirection != last.opposite {
      turns.append(newDirection)
    }
  }

  mutating func step() {
    guard state == .playing else { return }
    if !turns.isEmpty {
      direction = turns.removeFirst()
    }
    let head = moved(snake[0])
    let eats = head == food
    // The tail moves out of the way, unless the snake grows this step.
    let body = eats ? snake[...] : snake.dropLast()
    if body.contains(head) {
      state = .over
      return
    }
    snake.insert(head, at: 0)
    if !eats {
      snake.removeLast()
    } else if let cell = freeCells.randomElement() {
      food = cell
    } else {
      state = .over
    }
  }

  private func moved(_ cell: Cell) -> Cell {
    switch direction {
    case .up: Cell(x: cell.x, y: (cell.y + rows - 1) % rows)
    case .down: Cell(x: cell.x, y: (cell.y + 1) % rows)
    case .left: Cell(x: (cell.x + columns - 1) % columns, y: cell.y)
    case .right: Cell(x: (cell.x + 1) % columns, y: cell.y)
    }
  }

  private var freeCells: [Cell] {
    let taken = Set(snake)
    return (0..<rows).flatMap { y in (0..<columns).map { Cell(x: $0, y: y) } }.filter { !taken.contains($0) }
  }
}
