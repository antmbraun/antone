import AVFoundation
import SwiftUI

struct ContentView: View {
    @State private var showSettings = false
    @State private var keyCount = 13
    @State private var useColors = true
    @State private var useSoundOnly = false
    @StateObject private var toneGenerator = ToneGenerator()
    @StateObject private var gameManager: GameManager

    // Random pleasing frequency
    @State private var baseFrequency: Double = Double.random(in: 200...400)
    // Stable starting hue so colors don't shift on every re-render
    @State private var startingKeyHue: Double = Double.random(in: 0...1)

    init() {
        let tg = ToneGenerator()
        _toneGenerator = StateObject(wrappedValue: tg)
        _gameManager = StateObject(wrappedValue: GameManager(toneGenerator: tg))
    }

    // Semitone ratio in 12-tone equal temperament
    private func semitone(_ n: Double) -> Double {
        pow(2.0, n / 12.0)
    }

    // Calculate frequencies for all keys
    var frequencies: [Double] {
        guard keyCount > 1 else { return [baseFrequency] }

        // Semitone offsets for each scale (12-TET)
        let offsets: [Double]
        switch keyCount {
        // Major pentatonic: C D E G A
        case 5:
            offsets = [0, 2, 4, 7, 9]
        // Blues scale: C Eb F F# G Bb C
        case 7:
            offsets = [0, 3, 5, 6, 7, 10, 12]
        // Major scale: C D E F G A B C
        case 8:
            offsets = [0, 2, 4, 5, 7, 9, 11, 12]
        // Chromatic scale: all 12 semitones + octave
        case 13:
            offsets = Array(0...12).map { Double($0) }
        default:
            // Evenly divide the octave logarithmically for other counts
            return (0..<keyCount).map { index in
                baseFrequency * pow(2.0, Double(index) / Double(keyCount - 1))
            }
        }

        return offsets.map { baseFrequency * semitone($0) }
    }

    private var isActive: Bool {
        gameManager.gameState == .playing || gameManager.gameState == .waitingForInput
    }

    private func isHighlighted(_ keyIndex: Int) -> Bool {
        !useSoundOnly && gameManager.highlightedKey == keyIndex
    }

    private func keyColor(base: Color, keyIndex: Int) -> Color {
        if isHighlighted(keyIndex) {
            return Color.white
        }
        return useColors ? base : Color.white
    }

    private func handleKeyTap(_ keyIndex: Int) {
        guard gameManager.gameState == .waitingForInput else { return }
        gameManager.handleTap(keyIndex: keyIndex)
    }

    var body: some View {
        let saturation = 0.8
        let brightness = isActive ? 0.7 : 0.3
        let colors = (0..<keyCount).map { index -> Color in
            let hue = (startingKeyHue + Double(index) / Double(keyCount)).truncatingRemainder(
                dividingBy: 1.0)
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }

        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let containerWidth = max(geometry.size.width, geometry.size.height)
            let containerHeight = min(geometry.size.width, geometry.size.height)

            ZStack(alignment: .topLeading) {
                if keyCount == 13 {
                    pianoLayout(
                        colors: colors,
                        containerWidth: containerWidth,
                        containerHeight: containerHeight
                    )
                } else {
                    regularLayout(colors: colors)
                }
            }
            .frame(width: containerWidth, height: containerHeight)
            .rotationEffect(.degrees(isLandscape ? 0 : 90))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .clipped()
            .overlay {
                if !isLandscape {
                    rotatePrompt
                } else if gameManager.gameState == .idle {
                    idleOverlay
                } else if gameManager.gameState == .gameOver {
                    gameOverOverlay(containerWidth: containerWidth)
                } else if isActive {
                    activeOverlay(containerWidth: containerWidth)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            SettingsView(keyCount: $keyCount, useColors: $useColors, useSoundOnly: $useSoundOnly)
        }
    }

    // MARK: - Key layouts

    @ViewBuilder
    private func pianoLayout(
        colors: [Color], containerWidth: CGFloat, containerHeight: CGFloat
    ) -> some View {
        let whiteKeyIndices = [0, 2, 4, 5, 7, 9, 11, 12]
        let blackKeyIndices = [1, 3, 6, 8, 10]
        let whiteKeyCount = whiteKeyIndices.count
        let whiteKeyWidth = containerWidth / CGFloat(whiteKeyCount)
        let blackKeyWidth = whiteKeyWidth * 0.6
        let blackKeyHeight = containerHeight * 0.6

        // White keys
        HStack(spacing: 0) {
            ForEach(Array(whiteKeyIndices.enumerated()), id: \.offset) {
                _, colorIndex in
                keyColor(base: colors[colorIndex], keyIndex: colorIndex)
                    .frame(width: whiteKeyWidth, height: containerHeight)
                    .overlay(
                        isHighlighted(colorIndex)
                            ? Color.white.opacity(0.5) : Color.clear
                    )
                    .animation(.easeInOut(duration: 0.1), value: gameManager.highlightedKey)
                    .onTapGesture { handleKeyTap(colorIndex) }
                    .allowsHitTesting(gameManager.gameState == .waitingForInput)
                Color.black.frame(width: 2)
            }
        }

        // Black keys
        ForEach(blackKeyIndices, id: \.self) { blackKeyIndex in
            let precedingWhiteKeyIndex =
                whiteKeyIndices.last(where: { $0 < blackKeyIndex }) ?? 0
            let whiteKeyArrayIndex =
                whiteKeyIndices.firstIndex(of: precedingWhiteKeyIndex) ?? 0
            let xPosition = CGFloat(whiteKeyArrayIndex) * whiteKeyWidth + whiteKeyWidth

            (isHighlighted(blackKeyIndex) ? Color.white : Color.black)
                .frame(width: blackKeyWidth, height: blackKeyHeight)
                .animation(.easeInOut(duration: 0.1), value: gameManager.highlightedKey)
                .position(x: xPosition, y: blackKeyHeight / 2)
                .onTapGesture { handleKeyTap(blackKeyIndex) }
                .allowsHitTesting(gameManager.gameState == .waitingForInput)
        }
    }

    @ViewBuilder
    private func regularLayout(colors: [Color]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                if index > 0 {
                    Color.black.frame(width: 2)
                }

                keyColor(base: color, keyIndex: index)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        isHighlighted(index)
                            ? Color.white.opacity(0.5) : Color.clear
                    )
                    .animation(.easeInOut(duration: 0.1), value: gameManager.highlightedKey)
                    .onTapGesture { handleKeyTap(index) }
                    .allowsHitTesting(gameManager.gameState == .waitingForInput)
            }
        }
    }

    // MARK: - Overlays

    private var rotatePrompt: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 60))
                .foregroundColor(.white)
            Text("Please rotate your device to landscape mode")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(Color.black.opacity(0.7))
        .cornerRadius(20)
        .padding(40)
    }

    private var idleOverlay: some View {
        VStack(spacing: 40) {
            // High score display
            if gameManager.highScore > 0 {
                Text("High Score: \(gameManager.highScore)")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(12)
            }

            // Play button
            Button(action: {
                gameManager.startGame(
                    frequencies: frequencies,
                    keyCount: keyCount,
                    useSoundOnly: useSoundOnly
                )
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .background(
                        Circle().fill(
                            useColors ? Color.black.opacity(0.3) : Color.black))
            }

            // Settings button
            Button(action: {
                showSettings = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18))
                    Text("Settings")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(useColors ? Color.black.opacity(0.4) : Color.black)
                .cornerRadius(20)
            }
        }
    }

    private func activeOverlay(containerWidth: CGFloat) -> some View {
        ZStack {
            // Score and high score in top-left
            VStack(alignment: .leading, spacing: 2) {
                Text("Score: \(gameManager.score)")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                Text("Best: \(gameManager.highScore)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(10)
            .position(x: 70, y: 36)

            // Status indicator
            if gameManager.gameState == .playing {
                Text("Listen...")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.4))
                    .cornerRadius(8)
                    .position(x: containerWidth / 2, y: 30)
            } else if gameManager.gameState == .waitingForInput {
                HStack(spacing: 8) {
                    Text("Your turn!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    if useSoundOnly {
                        Button(action: {
                            gameManager.playHint()
                        }) {
                            Image(systemName: "ear")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(
                                    gameManager.isPlayingHint
                                        ? .yellow : .white.opacity(0.8)
                                )
                        }
                        .disabled(gameManager.isPlayingHint)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
                .position(x: containerWidth / 2, y: 30)
            }

            // Quit button in top-right
            Button(action: {
                gameManager.quit()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white.opacity(0.7))
            }
            .position(x: containerWidth - 40, y: 30)
        }
    }

    private func gameOverOverlay(containerWidth: CGFloat) -> some View {
        VStack(spacing: 20) {
            Text("Game Over")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)

            Text("Score: \(gameManager.score)")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)

            if gameManager.score >= gameManager.highScore && gameManager.score > 0 {
                Text("New High Score!")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.yellow)
            } else {
                Text("High Score: \(gameManager.highScore)")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
            }

            HStack(spacing: 20) {
                Button(action: {
                    gameManager.startGame(
                        frequencies: frequencies,
                        keyCount: keyCount,
                        useSoundOnly: useSoundOnly
                    )
                }) {
                    Text("Play Again")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(12)
                }

                Button(action: {
                    gameManager.quit()
                }) {
                    Text("Quit")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.6))
                        .cornerRadius(12)
                }
            }
            .padding(.top, 10)
        }
        .padding(40)
        .background(Color.black.opacity(0.8))
        .cornerRadius(20)
    }
}

#Preview {
    ContentView()
}
