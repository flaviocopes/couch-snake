import AVFoundation

/// The game's two sounds, from Snake/Sounds: a soft blip on every turn and a coin when it eats.
@MainActor
final class Sounds {
  private let turn = player("turn", volume: 0.25)
  private let food = player("food", volume: 0.35)

  init() {
    try? AVAudioSession.sharedInstance().setCategory(.ambient)
  }

  func playTurn() {
    restart(turn)
  }

  func playFood() {
    restart(food)
  }

  private func restart(_ player: AVAudioPlayer?) {
    player?.currentTime = 0
    player?.play()
  }

  private static func player(_ name: String, volume: Float) -> AVAudioPlayer? {
    guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
      let player = try? AVAudioPlayer(contentsOf: url)
    else { return nil }
    player.volume = volume
    player.prepareToPlay()
    return player
  }
}
