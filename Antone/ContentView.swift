import SwiftUI
import AVFoundation

struct ContentView: View {
    // Set default values for the state variables
    @State private var showSettings = false
    @State private var keyCount = 13
    @State private var useColors = true
    @State private var useSoundOnly = false
    @State private var playing = false
    @StateObject private var toneGenerator = ToneGenerator()
    @State private var baseFrequency: Double = Double.random(in: 200...400) // Random pleasing frequency
    
    // Calculate frequencies for all keys
    var frequencies: [Double] {
        guard keyCount > 1 else { return [baseFrequency] }
        return (0..<keyCount).map { index in
            baseFrequency * pow(2.0, Double(index) / Double(keyCount - 1))
        }
    }
    
    var body: some View {
        let startingKeyHue = Double.random(in: 0...1)
        let saturation = 0.8
        let brightness = playing ? 0.7 : 0.3
        let colors = (0..<keyCount).map { index -> Color in
            let hue = (startingKeyHue + Double(index) / Double(keyCount)).truncatingRemainder(dividingBy: 1.0)
            return Color(hue: hue, saturation: saturation, brightness: brightness)
        }

        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            let containerWidth = max(geometry.size.width, geometry.size.height)
            let containerHeight = min(geometry.size.width, geometry.size.height)
            
            ZStack(alignment: .topLeading) {
                if keyCount == 13 {
                    // Piano layout: white keys (full width) and black keys (narrower, raised)
                    let whiteKeyIndices = [0, 2, 4, 5, 7, 9, 11, 12] // White key positions
                    let blackKeyIndices = [1, 3, 6, 8, 10] // Black key positions
                    let whiteKeyCount = whiteKeyIndices.count
                    let whiteKeyWidth = containerWidth / CGFloat(whiteKeyCount)
                    let blackKeyWidth = whiteKeyWidth * 0.6
                    let blackKeyHeight = containerHeight * 0.6
                    
                    // White keys layer (background)
                    HStack(spacing: 0) {
                        ForEach(Array(whiteKeyIndices.enumerated()), id: \.offset) { whiteIndex, colorIndex in
                            let color = colors[colorIndex]
                            (useColors ? color : Color.white)
                                .frame(width: whiteKeyWidth, height: containerHeight)
                                .onTapGesture {
                                    if playing {
                                        toneGenerator.playTone(frequency: frequencies[colorIndex])
                                    }
                                }
                                .allowsHitTesting(playing)
                            Color.black
                                .frame(width: 2)
                        }
                    }
                    
                    // Black keys layer (overlay, positioned between white keys)
                    ForEach(blackKeyIndices, id: \.self) { blackKeyIndex in
                        let precedingWhiteKeyIndex = whiteKeyIndices.last(where: { $0 < blackKeyIndex }) ?? 0
                        let whiteKeyArrayIndex = whiteKeyIndices.firstIndex(of: precedingWhiteKeyIndex) ?? 0
                        let xPosition = CGFloat(whiteKeyArrayIndex) * whiteKeyWidth + whiteKeyWidth
                        
                        Color.black
                            .frame(width: blackKeyWidth, height: blackKeyHeight)
                            .position(x: xPosition, y: blackKeyHeight / 2)
                            .onTapGesture {
                                if playing {
                                    toneGenerator.playTone(frequency: frequencies[blackKeyIndex])
                                }
                            }
                            .allowsHitTesting(playing)
                    }
                } else {
                    // Regular layout for other button counts
                    HStack(spacing: 0) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            if index > 0 {
                                Color.black
                                    .frame(width: 2)
                            }
                            
                            (useColors ? color : Color.white)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .onTapGesture {
                                    if playing {
                                        toneGenerator.playTone(frequency: frequencies[index])
                                    }
                                }
                                .allowsHitTesting(playing)
                        }
                    }
                }
            }
            .frame(width: containerWidth, height: containerHeight)
            .rotationEffect(.degrees(isLandscape ? 0 : 90))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .clipped()
            .overlay {
                if !isLandscape {
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
                else if !playing {
                    VStack(spacing: 40) {
                        // Play button
                        Button(action: {
                            playing.toggle()
                        }) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white)
                                .background(Circle().fill(useColors ? Color.black.opacity(0.3) : Color.black))
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
                else if playing {
                    // Pause button in top right corner
                    Button(action: {
                        playing.toggle()
                    }) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: 40))
                            .foregroundColor(useColors ? Color.white : Color.black)
                    }
                    .position(x: containerWidth - 40, y: 40)
                }
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            SettingsView(keyCount: $keyCount, useColors: $useColors, useSoundOnly: $useSoundOnly)
        }
    }
}

#Preview {
    ContentView()
}
