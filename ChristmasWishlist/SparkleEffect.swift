//
//  SparkleEffect.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CoreMotion
import UIKit

// MARK: - Sparkle Particle
struct SparkleParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var delay: Double
    var depth: CGFloat // Depth layer for parallax effect (0.5 = background, 1.5 = foreground)
}

// MARK: - Sparkle Effect View
struct SparkleEffect: View {
    let particleCount: Int
    @State private var particles: [SparkleParticle] = []
    @State private var animate = false
    @State private var twinkle = false
    @StateObject private var motionManager = MotionManager()

    init(particleCount: Int = 12) {
        self.particleCount = particleCount
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    // Calculate parallax offset based on device motion and particle depth
                    let parallaxX = motionManager.roll * 10 * particle.depth
                    let parallaxY = motionManager.pitch * 10 * particle.depth

                    // Star shape for sparkle effect
                    Image(systemName: "star.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .font(.system(size: 8 * particle.scale))
                        .position(
                            x: particle.x + parallaxX,
                            y: particle.y + parallaxY
                        )
                        .opacity(twinkle ? particle.opacity : 0.2)
                        .scaleEffect(twinkle ? 1.2 : 0.6)
                        .rotationEffect(.degrees(twinkle ? 180 : 0))
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(particle.delay),
                            value: twinkle
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: motionManager.roll)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: motionManager.pitch)
                        .shadow(color: .white.opacity(0.8), radius: 4)
                }
            }
            .onAppear {
                generateParticles(in: geometry.size)
                twinkle = true
            }
        }
    }

    private func generateParticles(in size: CGSize) {
        particles = (0..<particleCount).map { index in
            SparkleParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: Double.random(in: 0.3...0.8),
                delay: Double.random(in: 0...1.0),
                depth: CGFloat.random(in: 0.5...1.5) // Varying depth creates layered parallax
            )
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
                        SparkleEffect(particleCount: 8)
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
