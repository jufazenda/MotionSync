//
//  ContentView.swift
//  MotionSyncMac
//
//  Created by júlia fazenda ruiz on 04/11/25.
//

import SwiftUI
import MotionSyncCore
import Combine

struct ContentView: View {
    @StateObject private var delegate = MotionDelegate()
    @StateObject private var session = MotionSession()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    Text("Conectado: \(session.connectedPeers.count) peer(s)")
                        .foregroundColor(.white)
                        .padding()
                    
                    Spacer()
                }
                
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 100, height: 100)
                    .position(delegate.position)
            }
            .onAppear {
                session.delegate = delegate
                delegate.screenSize = geometry.size
                session.startBrowsing()
            }
        }
    }
}

final class MotionDelegate: ObservableObject, MotionSessionDelegate {
    @Published var position = CGPoint(x: 400, y: 400)
    var screenSize: CGSize = .zero
    
    func didReceiveMotionData(_ data: MotionData) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Atualiza posição com base no movimento
            var newX = self.position.x + CGFloat(data.roll * 15)
            var newY = self.position.y - CGFloat(data.pitch * 15)
            
            // Limita aos bounds da tela (com margem de 50 pixels do quadrado)
            newX = max(50, min(self.screenSize.width - 50, newX))
            newY = max(50, min(self.screenSize.height - 50, newY))
            
            self.position = CGPoint(x: newX, y: newY)
        }
    }
}
