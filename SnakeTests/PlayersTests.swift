import Foundation
import Testing
@testable import Snake

struct PlayersTests {
  private let defaults = UserDefaults(suiteName: "snake-tests-\(UUID().uuidString)")!

  @Test func startsWithOnePlayerWhoKeepsTheOldBestScore() {
    defaults.set(42, forKey: "best")
    let players = Players(defaults: defaults)
    #expect(players.all.map(\.name) == ["PLAYER 1"])
    #expect(players.current.best == 42)
  }

  @Test func addingAPlayerMakesThemCurrent() {
    let players = Players(defaults: defaults)
    #expect(players.add("  Flavio "))
    #expect(players.current.name == "FLAVIO")
    #expect(players.all.count == 2)
  }

  @Test func namesFitTheLCDFont() {
    #expect(Players.name(from: "Chiara è qui!") == "CHIARA E Q")
    #expect(Players.name(from: "  two   words ") == "TWO WORDS")
  }

  @Test func refusesEmptyAndTakenNames() {
    let players = Players(defaults: defaults)
    #expect(!players.add(" ?! "))
    #expect(!players.add("player 1"))
    #expect(players.all.count == 1)
  }

  @Test func recordOnlyRaisesTheCurrentPlayersBest() {
    let players = Players(defaults: defaults)
    players.record(10)
    players.record(4)
    #expect(players.current.best == 10)
    players.add("Flavio")
    players.record(3)
    #expect(players.ranked.map(\.best) == [10, 3])
  }

  @Test func deletingKeepsAtLeastOnePlayer() {
    let players = Players(defaults: defaults)
    players.delete(players.current)
    #expect(players.all.count == 1)
    players.add("Flavio")
    players.delete(players.current)
    #expect(players.current.name == "PLAYER 1")
  }

  @Test func remembersPlayersBetweenLaunches() {
    let players = Players(defaults: defaults)
    players.add("Flavio")
    players.record(7)
    let reopened = Players(defaults: defaults)
    #expect(reopened.current.name == "FLAVIO")
    #expect(reopened.current.best == 7)
    #expect(reopened.all.count == 2)
  }
}
