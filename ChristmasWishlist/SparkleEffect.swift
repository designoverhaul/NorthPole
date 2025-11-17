//
//  SparkleEffect.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI

// MARK: - Sparkle Particle
struct SparkleParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var scale: CGFloat
    var opacity: Double
    var delay: Double
}

// MARK: - Sparkle Effect View
struct SparkleEffect: View {
    let particleCount: Int
    @State private var particles: [SparkleParticle] = []
    @State private var animate = false
    @State private var twinkle = false

    init(particleCount: Int = 12) {
        self.particleCount = particleCount
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
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
                        .position(x: particle.x, y: particle.y)
                        .opacity(twinkle ? particle.opacity : 0.2)
                        .scaleEffect(twinkle ? 1.2 : 0.6)
                        .rotationEffect(.degrees(twinkle ? 180 : 0))
                        .animation(
                            .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(particle.delay),
                            value: twinkle
                        )
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
                delay: Double.random(in: 0...1.0)
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
