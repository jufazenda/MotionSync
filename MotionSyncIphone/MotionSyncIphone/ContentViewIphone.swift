//
//  ContentView.swift
//  MotionSyncIphone
//
//  Created by júlia fazenda ruiz on 04/11/25.
//

import SwiftUI
import CoreMotion
import MotionSyncCore
import Combine
internal import MultipeerConnectivity

struct ContentView: View {
    @StateObject private var motionController = MotionController()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("📱 Motion Controller")
                .font(.title)
                .bold()
            
            Text("Movimente o iPhone para mover o quadrado no Mac")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            VStack(spacing: 10) {
                Text("Status da Conexão")
                    .font(.headline)
                
                Text(motionController.session.connectedPeers.isEmpty ? "🔴 Desconectado" : "🟢 Conectado")
                    .foregroundColor(motionController.session.connectedPeers.isEmpty ? .red : .green)
                    .font(.title2)
                
                if !motionController.session.connectedPeers.isEmpty {
                    ForEach(motionController.session.connectedPeers, id: \.self) { peer in
                        Text("Conectado a: \(peer.displayName)")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(10)
            
            Spacer()
            
            VStack(spacing: 10) {
                Text("Dados do Motion")
                    .font(.headline)
                
                HStack {
                    Text("Pitch:")
                    Text(String(format: "%.2f", motionController.currentPitch))
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Roll:")
                    Text(String(format: "%.2f", motionController.currentRoll))
                        .foregroundColor(.green)
                }
            }
            .padding()
            
            Spacer()
        }
        .padding()
        .onAppear {
            motionController.start()
        }
        .onDisappear {
            motionController.stop()
        }
    }
}

final class MotionController: ObservableObject {
    private let motionManager = CMMotionManager()
    let session = MotionSession()
    
    @Published var currentPitch: Double = 0
    @Published var currentRoll: Double = 0
    
    func start() {
        session.startAdvertising()
        
        motionManager.deviceMotionUpdateInterval = 0.05
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion, let self = self else { return }
            
            self.currentPitch = motion.attitude.pitch
            self.currentRoll = motion.attitude.roll
            
            let data = MotionData(pitch: motion.attitude.pitch,
                                  roll: motion.attitude.roll)
            self.session.send(data)
        }
    }
    
    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
