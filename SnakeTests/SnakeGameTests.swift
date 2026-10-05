import Testing
@testable import Snake

struct SnakeGameTests {
  /// A 10x10 game with the snake in the middle heading right, and the food out of the way.
  private func game(_ snake: [Cell] = [Cell(x: 5, y: 5), Cell(x: 4, y: 5), Cell(x: 3, y: 5)]) -> SnakeGame {
    var game = SnakeGame(columns: 10, rows: 10)
    game.snake = snake
    game.food = Cell(x: 0, y: 0)
    game.resume()
    return game
  }

  @Test func newGameWaitsWithFoodOffTheSnake() {
    let game = SnakeGame()
    #expect(game.state == .ready)
    #expect(game.snake.count == 3)
    #expect(!game.snake.contains(game.food))
  }

  @Test func movesOneCellPerStep() {
    var game = game()
    game.step()
    #expect(game.snake == [Cell(x: 6, y: 5), Cell(x: 5, y: 5), Cell(x: 4, y: 5)])
  }

  @Test func wrapsAroundTheEdges() {
    var game = game([Cell(x: 9, y: 5), Cell(x: 8, y: 5), Cell(x: 7, y: 5)])
    game.step()
    #expect(game.snake[0] == Cell(x: 0, y: 5))
    game.turn(.up)
    for _ in 0..<6 {
      game.step()
    }
    #expect(game.snake[0] == Cell(x: 0, y: 9))
    #expect(game.state == .playing)
  }

  @Test func ignoresTurningBack() {
    var game = game()
    game.turn(.left)
    game.step()
    #expect(game.snake[0] == Cell(x: 6, y: 5))
  }

  @Test func queuedTurnsApplyOnePerStep() {
    var game = game()
    game.turn(.down)
    game.turn(.left)
    game.step()
    #expect(game.snake[0] == Cell(x: 5, y: 6))
    game.step()
    #expect(game.snake[0] == Cell(x: 4, y: 6))
  }

  @Test func swipeStartsTheGame() {
    var game = SnakeGame()
    game.turn(.up)
    #expect(game.state == .playing)
  }

  @Test func growsAndScoresWhenItEats() {
    var game = game()
    game.food = Cell(x: 6, y: 5)
    game.step()
    #expect(game.snake.count == 4)
    #expect(game.score == 1)
    #expect(!game.snake.contains(game.food))
  }

  @Test func diesRunningIntoItself() {
    var game = game([Cell(x: 5, y: 5), Cell(x: 4, y: 5), Cell(x: 4, y: 6), Cell(x: 5, y: 6), Cell(x: 6, y: 6)])
    game.turn(.down)
    game.step()
    #expect(game.state == .over)
  }

  @Test func canFollowItsOwnTail() {
    var game = game([Cell(x: 5, y: 5), Cell(x: 4, y: 5), Cell(x: 4, y: 6), Cell(x: 5, y: 6)])
    game.turn(.down)
    game.step()
    #expect(game.state == .playing)
    #expect(game.snake[0] == Cell(x: 5, y: 6))
  }

  @Test func pausedGameDoesNotMove() {
    var game = game()
    game.pause()
    game.step()
    #expect(game.snake[0] == Cell(x: 5, y: 5))
  }
}
