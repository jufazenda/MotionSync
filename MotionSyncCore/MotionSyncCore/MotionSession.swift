//
//  MotionSession.swift
//  MotionSyncCore
//
//  Created by júlia fazenda ruiz on 04/11/25.
//

import Foundation
import SwiftUI
import MultipeerConnectivity
import Combine
#if os(iOS)
import UIKit
#endif

public protocol MotionSessionDelegate: AnyObject {
    func didReceiveMotionData(_ data: MotionData, from peerID: MCPeerID)
}

public struct MotionData: Codable {
    public let pitch: Double
    public let roll: Double
    
    public init(pitch: Double, roll: Double) {
        self.pitch = pitch
        self.roll = roll
    }
}

public final class MotionSession: NSObject, ObservableObject {
    @Published public var connectedPeers: [MCPeerID] = []
    
    public var myPeerID: MCPeerID { myPeerId }
    
    private let serviceType = "motionsync"
    #if os(macOS)
    private let myPeerId = MCPeerID(displayName: Host.current().localizedName ?? UUID().uuidString)
    #elseif os(iOS)
    private let myPeerId = MCPeerID(displayName: "\(UIDevice.current.name)-\(UUID().uuidString.prefix(4))")
    #else
    private let myPeerId = MCPeerID(displayName: UUID().uuidString)
    #endif
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    
    public weak var delegate: MotionSessionDelegate?

    public override init() {
        super.init()
        session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }
    
    // iPhone → envia dados
    public func startAdvertising() {
        print("🚀 [ADVERTISER] Iniciando advertising...")
        print("📱 [ADVERTISER] Nome do dispositivo: \(myPeerId.displayName)")
        print("🔧 [ADVERTISER] Service type: \(serviceType)")
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        print("✅ [ADVERTISER] Advertising iniciado!")
    }
    
    // Mac → procura peers
    public func startBrowsing() {
        print("🚀 [BROWSER] Iniciando browsing...")
        print("💻 [BROWSER] Nome do dispositivo: \(myPeerId.displayName)")
        print("🔧 [BROWSER] Service type: \(serviceType)")
        
        browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
        
        print("✅ [BROWSER] Browsing iniciado!")
    }

    public func send(_ data: MotionData) {
        guard !session.connectedPeers.isEmpty else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            try? session.send(encoded, toPeers: session.connectedPeers, with: .reliable)
        }
    }
}

extension MotionSession: MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("🔄 [SESSION] Peer \(peerID.displayName) mudou estado")
        
        DispatchQueue.main.async { [weak self] in
            self?.connectedPeers = session.connectedPeers
            
            switch state {
            case .connected:
                print("✅ [SESSION] CONECTADO a \(peerID.displayName)")
                print("👥 [SESSION] Total de peers conectados: \(session.connectedPeers.count)")
            case .connecting:
                print("🔄 [SESSION] CONECTANDO a \(peerID.displayName)...")
            case .notConnected:
                print("❌ [SESSION] DESCONECTADO de \(peerID.displayName)")
                print("👥 [SESSION] Total de peers conectados: \(session.connectedPeers.count)")
            @unknown default:
                print("⚠️ [SESSION] Estado desconhecido")
                break
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let motionData = try? JSONDecoder().decode(MotionData.self, from: data) {
            // print("📦 [SESSION] Dados recebidos de \(peerID.displayName)") // Comentado para não spammar
            delegate?.didReceiveMotionData(motionData, from: peerID)
        }
    }

    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("❌ [ADVERTISER] ERRO ao iniciar advertising: \(error.localizedDescription)")
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                           withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        print("📥 [ADVERTISER] Convite recebido de: \(peerID.displayName)")
        print("✅ [ADVERTISER] Aceitando convite automaticamente...")
        invitationHandler(true, session)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        print("🔍 [BROWSER] Peer encontrado: \(peerID.displayName)")
        print("📤 [BROWSER] Enviando convite para: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("📡 [BROWSER] Peer perdido: \(peerID.displayName)")
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("❌ [BROWSER] ERRO ao iniciar browsing: \(error.localizedDescription)")
    }
}
