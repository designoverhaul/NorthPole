//
//  ParallaxEffect.swift
//  ChristmasWishlist
//
//  Created by Claude Code
//

import SwiftUI
import CoreMotion
import Combine

// MARK: - Motion Manager
class MotionManager: ObservableObject {
    private var motionManager: CMMotionManager
    @Published var roll: Double = 0
    @Published var pitch: Double = 0

    init() {
        self.motionManager = CMMotionManager()
        self.motionManager.deviceMotionUpdateInterval = 1/60
        self.startMotionUpdates()
    }

    func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device motion is not available")
            return
        }

        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            // Get roll and pitch from device motion
            // Roll: tilting left/right, Pitch: tilting forward/backward
            self?.roll = motion.attitude.roll
            self?.pitch = motion.attitude.pitch
        }
    }

    func stopMotionUpdates() {
        motionManager.stopDeviceMotionUpdates()
    }

    deinit {
        stopMotionUpdates()
    }
}

// MARK: - 3D Parallax View Modifier
struct Parallax3DEffect: ViewModifier {
    @StateObject private var motionManager = MotionManager()

    // Maximum rotation angles in degrees
    let maxRotation: Double = 15

    func body(content: Content) -> some View {
        let xRotation = -motionManager.pitch * (maxRotation * 2)
        let yRotation = motionManager.roll * (maxRotation * 2)

        content
            .rotation3DEffect(
                .degrees(xRotation),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .rotation3DEffect(
                .degrees(yRotation),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.5
            )
            .overlay(
                // Dynamic glare effect
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.3),
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.1),
                        Color.white.opacity(0.0)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .rotationEffect(.degrees(yRotation * 2))
                .offset(
                    x: yRotation * 3,
                    y: xRotation * 3
                )
                .blendMode(.overlay)
                .allowsHitTesting(false)
            )
            .shadow(
                color: Color.black.opacity(0.25),
                radius: 20,
                x: yRotation * 0.5,
                y: xRotation * 0.5 + 8
            )
            .shadow(
                color: Color.black.opacity(0.1),
                radius: 10,
                x: yRotation * 0.3,
                y: xRotation * 0.3 + 4
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: motionManager.roll)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: motionManager.pitch)
    }
}

// MARK: - View Extension
extension View {
    func parallax3D() -> some View {
        modifier(Parallax3DEffect())
    }
}
