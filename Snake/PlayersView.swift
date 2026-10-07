import SwiftUI

/// The scoreboard, and the way to change player: everyone ranked by best score. Click a name to
/// play as them, hold it to delete it, or add a new one at the bottom. Back closes it.
struct PlayersView: View {
  let players: Players
  let background: Color
  let choose: (Player) -> Void
  @State private var newName = ""
  @State private var adding = false
  @FocusState private var focused: UUID?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 40) {
      VStack(alignment: .leading, spacing: 12) {
        Text("PLAYERS")
          .font(.system(size: 80, weight: .black, design: .monospaced))
        Text("Click a name to play. Hold it to delete it.")
          .font(.system(size: 28, weight: .semibold, design: .monospaced))
          .opacity(0.7)
      }
      ScrollView {
        VStack(spacing: 16) {
          ForEach(Array(players.ranked.enumerated()), id: \.element.id) { rank, player in
            Button {
              choose(player)
            } label: {
              HStack(spacing: 0) {
                Text("\(rank + 1)")
                  .frame(width: 90, alignment: .leading)
                Text(player.name)
                Spacer()
                if player.id == players.currentID {
                  Text("PLAYING")
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .padding(.trailing, 40)
                }
                Text(String(format: "%04d", player.best))
              }
            }
            .buttonStyle(RowStyle(background: background))
            .focused($focused, equals: player.id)
            .contextMenu {
              if players.all.count > 1 {
                Button("Delete \(player.name)", role: .destructive) {
                  players.delete(player)
                }
              }
            }
          }
          Button("+ ADD A PLAYER") {
            adding = true
          }
          .buttonStyle(RowStyle(background: background, dashed: true))
        }
        .padding(8)
      }
      .scrollClipDisabled()
    }
    .frame(width: 1100)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .foregroundStyle(Color.ink)
    .background(background)
    .defaultFocus($focused, players.currentID)
    .onExitCommand { dismiss() }
    .alert("New player", isPresented: $adding) {
      TextField("Name", text: $newName)
      Button("Add", action: add)
      Button("Cancel", role: .cancel) {
        newName = ""
      }
    } message: {
      Text("Up to \(Players.nameLength) letters and numbers.")
    }
  }

  /// A new player becomes the current one and goes to the top of the list's focus.
  private func add() {
    if players.add(newName) {
      focused = players.currentID
    }
    newName = ""
  }
}

/// A row that turns to ink when it has focus, like a selected line on the LCD.
private struct RowStyle: ButtonStyle {
  let background: Color
  var dashed = false

  func makeBody(configuration: Configuration) -> some View {
    Row(focusedBackground: background, pressed: configuration.isPressed, dashed: dashed) {
      configuration.label
    }
  }
}

private struct Row<Content: View>: View {
  let focusedBackground: Color
  let pressed: Bool
  let dashed: Bool
  @ViewBuilder let content: Content
  @Environment(\.isFocused) private var focused

  var body: some View {
    content
      .font(.system(size: 44, weight: .bold, design: .monospaced))
      .padding(.horizontal, 32)
      .padding(.vertical, 18)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(focused ? focusedBackground : Color.ink)
      .background(focused ? Color.ink : Color.clear)
      .overlay(Rectangle().strokeBorder(Color.ink, style: StrokeStyle(lineWidth: 4, dash: dashed ? [12, 8] : [])))
      .scaleEffect(pressed ? 0.98 : 1)
  }
}
