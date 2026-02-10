# Hookshot

An arena shooter with grappling hooks, built for the 7 Day FPS game jam.

## About

Hookshot is a fast-paced multiplayer FPS where movement is king. Grapple across arenas, blast your opponents with rockets, and try not to fall into the void.

## Controls

| Action | Keyboard | Controller |
|--------|----------|------------|
| Move | WASD | Left Stick |
| Look | Mouse | Right Stick |
| Jump | Space | A |
| Fire | Left Click | RT |
| Grapple | F | LB |
| Switch Weapon | Q | Y |
| Reload | R | X |
| Zoom | Right Click | LT |
| Scoreboard | Tab | Back |
| Help | H | - |

## Building

Requires [Godot 4.1](https://godotengine.org/).

1. Open the project in Godot
2. Export for your target platform (Linux, Windows, or macOS)

## Multiplayer

The game includes a matchmaker server written in Go (`Server/matchmaker/`). For local testing, the debug scene connects directly without matchmaking.

## License

See [LICENSE](LICENSE) for details.

## Credits

Made by [cowboyscott](https://cowboyscott.gg)
