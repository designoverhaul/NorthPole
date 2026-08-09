//
//  SparkleEffect.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import UIKit

// MARK: - Sparkle Placement
/// A sparkle's resting spot, in unit space relative to the decorated view.
/// Values just outside 0...1 let a sparkle sit slightly past the edge.
struct SparklePlacement: Identifiable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let delay: Double
}

// MARK: - Sparkle Effect View
struct SparkleEffect: View {
    /// Hand-placed so sparkles frame the view instead of scattering over its label.
    private static let placements: [SparklePlacement] = [
        SparklePlacement(id: 0, x: 0.05, y: 0.24, size: 11, delay: 0.0),
        SparklePlacement(id: 1, x: 0.94, y: 0.20, size: 8, delay: 1.3),
        SparklePlacement(id: 2, x: 0.82, y: 0.80, size: 12, delay: 2.6),
        SparklePlacement(id: 3, x: 0.18, y: 0.84, size: 8, delay: 3.9),
        SparklePlacement(id: 4, x: 0.50, y: -0.08, size: 7, delay: 2.0),
        SparklePlacement(id: 5, x: 1.03, y: 0.60, size: 7, delay: 4.6)
    ]

    /// One half of the twinkle cycle. Slow enough that the pulse reads as
    /// ambient shimmer rather than motion.
    private static let twinkleDuration: Double = 3.6

    let particleCount: Int
    @State private var twinkle = false

    init(particleCount: Int = 6) {
        self.particleCount = particleCount
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(Array(Self.placements.prefix(particleCount))) { placement in
                    Image(systemName: "sparkle")
                        .font(.system(size: placement.size, weight: .medium))
                        .foregroundStyle(.white)
                        .shadow(color: .white.opacity(0.5), radius: 2)
                        .opacity(twinkle ? 0.9 : 0.5)
                        .scaleEffect(twinkle ? 1.0 : 0.92)
                        .animation(
                            .easeInOut(duration: Self.twinkleDuration)
                            .repeatForever(autoreverses: true)
                            .delay(placement.delay),
                            value: twinkle
                        )
                        .position(
                            x: placement.x * geometry.size.width,
                            y: placement.y * geometry.size.height
                        )
                }
            }
            .onAppear { twinkle = true }
        }
    }
}

// MARK: - Sparkle Modifier
struct SparkleModifier: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        SparkleEffect()
                            .allowsHitTesting(false)
                    }
                }
            )
    }
}

extension View {
    func sparkle(isActive: Bool = true) -> some View {
        modifier(SparkleModifier(isActive: isActive))
    }
}

// MARK: - Success Sparkle Burst
struct SuccessSparkle: View {
    @State private var animate = false
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.goldShimmer, Color.gold],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 8, height: 8)
                    .offset(y: animate ? -100 : 0)
                    .opacity(animate ? 0 : 1)
                    .rotationEffect(.degrees(Double(index) * 22.5))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animate = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onComplete()
            }
        }
    }
}

// MARK: - Falling Snow Effect
struct Snowflake: Identifiable {
    let id = UUID()
    var startX: CGFloat
    var startY: CGFloat
    var size: CGFloat
    var opacity: Double
    var fallDuration: Double
    var drift: CGFloat
    var flutterSpeed: Double // Speed for side-to-side flutter
    var flutterAmount: CGFloat // Amount of side-to-side movement
    var startTime: Date
}

struct FallingSnowEffect: View {
    let snowflakeCount: Int
    @State private var snowflakes: [Snowflake] = []
    @State private var startTime: Date = Date()

    init(snowflakeCount: Int = 25) {
        self.snowflakeCount = snowflakeCount
    }

    var body: some View {
        GeometryReader { geometry in
            let screenSize = UIScreen.main.bounds.size
            TimelineView(.periodic(from: .now, by: 0.05)) { context in
                ZStack {
                    ForEach(snowflakes) { snowflake in
                        let elapsed = context.date.timeIntervalSince(snowflake.startTime)
                        let progress = min(elapsed / snowflake.fallDuration, 1.0)
                        // Fall from very top to bottom of full screen
                        let fallDistance = screenSize.height + 200
                        let currentY = snowflake.startY + fallDistance * progress
                        // Minimal side-to-side flutter (very subtle)
                        let flutterX = sin(elapsed * snowflake.flutterSpeed) * snowflake.flutterAmount
                        
                        Text("❄️")
                            .font(.system(size: snowflake.size))
                            .blur(radius: snowflake.size > 30 ? CGFloat(snowflake.size - 30) * 0.3 : 0)
                            .position(
                                x: snowflake.startX + flutterX,
                                y: currentY
                            )
                            .opacity(progress < 1.0 ? snowflake.opacity : 0)
                            .rotationEffect(.degrees(elapsed * 20)) // Simple slow rotation
                    }
                }
            }
            .onAppear {
                startTime = Date()
                let screenSize = UIScreen.main.bounds.size
                generateSnowflakes(in: screenSize)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func generateSnowflakes(in screenSize: CGSize) {
        snowflakes = (0..<snowflakeCount).map { _ in
            let flakeSize = CGFloat.random(in: 20...40) // Much larger snowflakes
            return Snowflake(
                startX: CGFloat.random(in: 0...screenSize.width),
                startY: -100, // Start from the very top edge of screen (off-screen above header)
                size: flakeSize,
                opacity: Double.random(in: 0.8...1.0), // More visible
                fallDuration: Double.random(in: 4...7), // Shorter duration for quick fall
                drift: 0, // No drift - just fall straight down
                flutterSpeed: Double.random(in: 0.2...0.8), // Very slow flutter
                flutterAmount: CGFloat.random(in: 3...10), // Minimal side-to-side movement
                startTime: startTime.addingTimeInterval(Double.random(in: 0...0.5)) // Start almost immediately
            )
        }
    }
}

extension View {
    func fallingSnow(isActive: Bool = true, count: Int = 30) -> some View {
        self
            .overlay(
                Group {
                    if isActive {
                        FallingSnowEffect(snowflakeCount: count)
                    }
                }
            )
    }
}
