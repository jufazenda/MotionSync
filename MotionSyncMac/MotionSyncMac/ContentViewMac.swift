//
//  ContentView.swift
//  MotionSyncMac
//
//  Created by júlia fazenda ruiz on 04/11/25.
//

import SwiftUI
import MotionSyncCore
import Combine
import MultipeerConnectivity

class PeersState: ObservableObject {
    @Published var peerPositions: [String: CGPoint] = [:]
}

class ContentViewModel: ObservableObject, MotionSessionDelegate {
    @Published var session = MotionSession()
    @Published var peersState = PeersState()
    @Published var screenSize: CGSize = .zero
    
    // Velocity dictionary to keep velocity per peer for inertia handling
    @Published var peerVelocities: [String: CGPoint] = [:]
    
    // Local peer fixed position for testing
    let localPeerPosition = CGPoint(x: 400, y: 400)
    
    // Sensitivity and damping constants
    private let sensitivity: CGFloat = 25
    private let damping: CGFloat = 0.9
    
    // Computed property to get all peers including local
    var allPeers: [MCPeerID] {
        [session.myPeerID] + session.connectedPeers
    }
    
    func onAppear(with size: CGSize) {
        screenSize = size
        session.delegate = self
        session.startBrowsing()
    }
    
    func didReceiveMotionData(_ data: MotionData, from peerID: MCPeerID) {
        DispatchQueue.main.async {
            let peerName = peerID.displayName
            
            // Get current position, default center of screen
            let currentPosition = self.peersState.peerPositions[peerName] ?? CGPoint(x: self.screenSize.width / 2, y: self.screenSize.height / 2)
            // Get current velocity or zero
            let currentVelocity = self.peerVelocities[peerName] ?? CGPoint.zero
            
            // Update velocity based on motion data and sensitivity
            var newVelocity = currentVelocity
            newVelocity.x += CGFloat(data.roll) * self.sensitivity
            newVelocity.y -= CGFloat(data.pitch) * self.sensitivity
            
            // Apply damping (inertia)
            newVelocity.x *= self.damping
            newVelocity.y *= self.damping
            
            // Update position
            var newX = currentPosition.x + newVelocity.x
            var newY = currentPosition.y + newVelocity.y
            
            // Clamp position within screen bounds with 50pt margin
            newX = max(50, min(self.screenSize.width - 50, newX))
            newY = max(50, min(self.screenSize.height - 50, newY))
            
            // Save updated velocity and position
            self.peerVelocities[peerName] = newVelocity
            self.peersState.peerPositions[peerName] = CGPoint(x: newX, y: newY)
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ContentViewModel()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Conectado: \(viewModel.session.connectedPeers.count) peer(s)")
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                }
                
                ForEach(viewModel.session.connectedPeers, id: \.self) { peer in
                    let position = viewModel.peersState.peerPositions[peer.displayName]
                        ?? CGPoint(x: viewModel.screenSize.width / 2, y: viewModel.screenSize.height / 2)
                    let colors: [Color] = [.yellow, .blue,  .pink, .purple, .cyan, .white]
                    let color = colors[abs(peer.displayName.hashValue) % colors.count]

                    Rectangle()
                        .fill(color)
                        .frame(width: 100, height: 100)
                        .position(position)
                        .overlay(
                            Text(peer.displayName)
                                .foregroundColor(.black)
                        )
                }

                // quadrado do próprio Mac
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 100, height: 100)
                    .position(viewModel.localPeerPosition)
                    .overlay(Text("Mac").foregroundColor(.black))
            }
            .onAppear {
                viewModel.onAppear(with: geometry.size)
            }
        }
    }
}
