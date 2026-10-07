import Foundation
import Observation

struct Player: Codable, Identifiable, Equatable {
  var id = UUID()
  var name: String
  var best = 0
}

/// The people who play on this Apple TV, each with their own best score, saved in UserDefaults.
/// There's always at least one player, and one of them is the current one.
@Observable
final class Players {
  static let nameLength = 10

  private(set) var all: [Player]
  private(set) var currentID: UUID
  @ObservationIgnored private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    var players = [Player]()
    if let data = defaults.data(forKey: "players"),
      let saved = try? JSONDecoder().decode([Player].self, from: data)
    {
      players = saved
    }
    if players.isEmpty {
      // Before players, the app kept a single best score.
      players = [Player(name: "PLAYER 1", best: defaults.integer(forKey: "best"))]
    }
    let savedID = defaults.string(forKey: "player").flatMap(UUID.init)
    all = players
    currentID = players.first { $0.id == savedID }?.id ?? players[0].id
  }

  var current: Player {
    all.first { $0.id == currentID } ?? all[0]
  }

  /// The scoreboard: the best score first.
  var ranked: [Player] {
    all.sorted { $0.best > $1.best }
  }

  /// Turns typed text into a name the LCD font can draw: letters without accents, digits
  /// and spaces, uppercased and cut to `nameLength`.
  static func name(from text: String) -> String {
    let folded = text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).uppercased()
    let kept = folded.filter { ("A"..."Z").contains($0) || ("0"..."9").contains($0) || $0 == " " }
    return String(kept.split(separator: " ").joined(separator: " ").prefix(nameLength))
  }

  /// Adds a player and makes them the current one. Returns false for an empty or taken name.
  @discardableResult
  func add(_ text: String) -> Bool {
    let name = Self.name(from: text)
    guard !name.isEmpty, !all.contains(where: { $0.name == name }) else { return false }
    let player = Player(name: name)
    all.append(player)
    currentID = player.id
    save()
    return true
  }

  func select(_ player: Player) {
    guard all.contains(player) else { return }
    currentID = player.id
    save()
  }

  /// Deletes a player, unless they're the last one. Deleting the current player moves to the next best.
  func delete(_ player: Player) {
    guard all.count > 1 else { return }
    all.removeAll { $0.id == player.id }
    if currentID == player.id {
      currentID = ranked[0].id
    }
    save()
  }

  /// Raises the current player's best score when a game goes past it.
  func record(_ score: Int) {
    guard let index = all.firstIndex(where: { $0.id == currentID }), score > all[index].best else { return }
    all[index].best = score
    save()
  }

  private func save() {
    defaults.set(try? JSONEncoder().encode(all), forKey: "players")
    defaults.set(currentID.uuidString, forKey: "player")
  }
}
