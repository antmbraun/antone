import Foundation
import SwiftUI

enum GameState {
    case idle
    case playing
    case waitingForInput
    case gameOver
}

@MainActor
class GameManager: ObservableObject {
    @Published var sequence: [Int] = []
    @Published var playerIndex: Int = 0
    @Published var score: Int = 0
    @Published var highScore: Int = 0
    @Published var gameState: GameState = .idle
    @Published var highlightedKey: Int? = nil

    private var toneGenerator: ToneGenerator
    private var frequencies: [Double] = []
    private var keyCount: Int = 0
    private var useSoundOnly: Bool = false
    @Published var isPlayingHint: Bool = false
    private var playbackTask: Task<Void, Never>?
    private var hintTask: Task<Void, Never>?

    private static let highScoreKey = "antone_high_score"

    init(toneGenerator: ToneGenerator) {
        self.toneGenerator = toneGenerator
        self.highScore = Self.loadHighScore()
    }

    func startGame(frequencies: [Double], keyCount: Int, useSoundOnly: Bool) {
        self.frequencies = frequencies
        self.keyCount = keyCount
        self.useSoundOnly = useSoundOnly

        sequence = []
        playerIndex = 0
        score = 0
        isPlayingHint = false
        gameState = .playing

        if useSoundOnly {
            // Play range hint first, then start the game
            playbackTask?.cancel()
            playbackTask = Task {
                await playRangeHint()
                guard !Task.isCancelled else { return }
                appendAndPlay()
            }
        } else {
            appendAndPlay()
        }
    }

    func quit() {
        playbackTask?.cancel()
        playbackTask = nil
        hintTask?.cancel()
        hintTask = nil
        highlightedKey = nil
        isPlayingHint = false
        gameState = .idle
    }

    func playHint() {
        guard gameState == .waitingForInput, useSoundOnly else { return }
        hintTask?.cancel()
        hintTask = Task {
            await playRangeHint()
        }
    }

    private func playRangeHint() async {
        guard !frequencies.isEmpty else { return }
        isPlayingHint = true

        let lowestIndex = 0
        let highestIndex = frequencies.count - 1

        // Play lowest key 3 times
        for _ in 0..<3 {
            guard !Task.isCancelled else { break }
            highlightedKey = lowestIndex
            await toneGenerator.playToneAndWait(
                frequency: frequencies[lowestIndex], duration: 0.25)
            highlightedKey = nil
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        // Play highest key 3 times
        for _ in 0..<3 {
            guard !Task.isCancelled else { break }
            highlightedKey = highestIndex
            await toneGenerator.playToneAndWait(
                frequency: frequencies[highestIndex], duration: 0.25)
            highlightedKey = nil
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        highlightedKey = nil
        isPlayingHint = false
    }

    func handleTap(keyIndex: Int) {
        guard gameState == .waitingForInput else { return }

        // Play the tapped tone so the player hears feedback
        if keyIndex < frequencies.count {
            toneGenerator.playTone(frequency: frequencies[keyIndex])
        }

        if keyIndex == sequence[playerIndex] {
            playerIndex += 1
            if playerIndex >= sequence.count {
                // Full sequence matched
                score += 1
                appendAndPlay()
            }
        } else {
            // Wrong key — game over
            gameState = .gameOver
            if score > highScore {
                highScore = score
                Self.saveHighScore(highScore)
            }
        }
    }

    private func appendAndPlay() {
        let nextKey = Int.random(in: 0..<keyCount)
        sequence.append(nextKey)
        playerIndex = 0
        gameState = .playing

        playbackTask?.cancel()
        playbackTask = Task {
            await playSequence()
        }
    }

    private func playSequence() async {
        // Brief pause before playback starts
        try? await Task.sleep(nanoseconds: 500_000_000)

        for keyIndex in sequence {
            guard !Task.isCancelled else { return }

            // Highlight the key (unless sound-only mode)
            if !useSoundOnly {
                highlightedKey = keyIndex
            }

            // Play the tone and wait for it to finish
            if keyIndex < frequencies.count {
                await toneGenerator.playToneAndWait(
                    frequency: frequencies[keyIndex], duration: 0.4)
            }

            highlightedKey = nil

            // Gap between notes
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        guard !Task.isCancelled else { return }
        gameState = .waitingForInput
    }

    private static func loadHighScore() -> Int {
        UserDefaults.standard.integer(forKey: highScoreKey)
    }

    private static func saveHighScore(_ score: Int) {
        UserDefaults.standard.set(score, forKey: highScoreKey)
    }
}
