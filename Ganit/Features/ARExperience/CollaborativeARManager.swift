import Foundation
import RealityKit
import ARKit
import MultipeerConnectivity
import Combine

#if os(iOS)

// MARK: - Collaborative AR Manager

/// Manages multipeer AR sessions where two kids solve problems together.
/// Uses MultipeerConnectivity + ARKit collaboration data for shared anchors.
@MainActor
class CollaborativeARManager: NSObject, ObservableObject {

    @Published var isHost = false
    @Published var connectedPeers: [String] = []
    @Published var connectionState: ConnectionState = .disconnected
    @Published var sharedProblem: SharedProblem?
    @Published var peerActions: [PeerAction] = []

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private let peerID: MCPeerID
    private let serviceType = "ganit-collab"
    private var arSession: ARSession?

    enum ConnectionState: String {
        case disconnected, searching, connecting, connected
    }

    struct SharedProblem: Codable {
        let question: String
        let targetNumber: Int
        let type: ProblemType

        enum ProblemType: String, Codable {
            case counting    // Both kids count objects together
            case grouping    // One places, other groups
            case addition    // Each kid handles one addend
        }
    }

    struct PeerAction: Codable, Identifiable {
        let id: UUID
        let peerName: String
        let action: ActionType
        let timestamp: Date
        let value: Int?

        enum ActionType: String, Codable {
            case placedBlock, groupedBlocks, countedTo, ready, celebrate
        }
    }

    // MARK: - Init

    override init() {
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        super.init()
    }

    // MARK: - Host a Session

    func startHosting(arSession: ARSession) {
        self.arSession = arSession
        isHost = true
        connectionState = .searching

        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        advertiser = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()

        // Enable collaboration on AR session
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.isCollaborationEnabled = true
        arSession.run(config)
    }

    // MARK: - Join a Session

    func startBrowsing(arSession: ARSession) {
        self.arSession = arSession
        isHost = false
        connectionState = .searching

        let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        browser = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()

        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.isCollaborationEnabled = true
        arSession.run(config)
    }

    // MARK: - Share Problem

    func shareProblem(_ problem: SharedProblem) {
        sharedProblem = problem
        guard let session = session, !session.connectedPeers.isEmpty else { return }

        do {
            let data = try JSONEncoder().encode(problem)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[CollaborativeAR] Failed to share problem: \(error)")
        }
    }

    // MARK: - Send Action

    func sendAction(_ actionType: PeerAction.ActionType, value: Int? = nil) {
        let action = PeerAction(
            id: UUID(),
            peerName: peerID.displayName,
            action: actionType,
            timestamp: Date(),
            value: value
        )

        peerActions.append(action)

        guard let session = session, !session.connectedPeers.isEmpty else { return }
        do {
            let data = try JSONEncoder().encode(action)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[CollaborativeAR] Failed to send action: \(error)")
        }
    }

    // MARK: - Share AR Collaboration Data

    func sendCollaborationData(_ data: Data) {
        guard let session = session, !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("[CollaborativeAR] Failed to send collaboration data: \(error)")
        }
    }

    // MARK: - Disconnect

    func disconnect() {
        session?.disconnect()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        connectionState = .disconnected
        connectedPeers = []
        sharedProblem = nil
        peerActions = []
    }
}

// MARK: - MCSessionDelegate

extension CollaborativeARManager: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                connectionState = .connected
                connectedPeers = session.connectedPeers.map(\.displayName)
            case .connecting:
                connectionState = .connecting
            case .notConnected:
                connectedPeers = session.connectedPeers.map(\.displayName)
                if session.connectedPeers.isEmpty {
                    connectionState = .disconnected
                }
            @unknown default:
                break
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            // Try to decode as SharedProblem
            if let problem = try? JSONDecoder().decode(SharedProblem.self, from: data) {
                sharedProblem = problem
                return
            }

            // Try to decode as PeerAction
            if let action = try? JSONDecoder().decode(PeerAction.self, from: data) {
                peerActions.append(action)
                return
            }

            // AR collaboration data — pass to AR session
            if let arSession = arSession,
               let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data) {
                arSession.update(with: collaborationData)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension CollaborativeARManager: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Auto-accept for now (in production, show a confirmation UI)
        invitationHandler(true, session)
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension CollaborativeARManager: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Auto-invite for now
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 30)
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

// MARK: - Collaborative AR View

import SwiftUI

struct CollaborativeARView: View {
    @StateObject private var collabManager = CollaborativeARManager()
    @State private var showPeerBrowser = false

    var body: some View {
        ZStack {
            // AR content placeholder
            Color.black.opacity(0.9)
                .edgesIgnoringSafeArea(.all)

            VStack {
                // Connection status
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(collabManager.connectionState.rawValue.capitalized)
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    if !collabManager.connectedPeers.isEmpty {
                        Text("With: \(collabManager.connectedPeers.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)

                Spacer()

                // Problem display
                if let problem = collabManager.sharedProblem {
                    VStack(spacing: 8) {
                        Text(problem.question)
                            .font(.title2.bold())
                            .foregroundColor(.white)
                        Text("Target: \(problem.targetNumber)")
                            .font(.headline)
                            .foregroundColor(.yellow)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                }

                // Peer actions log
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(collabManager.peerActions.suffix(5)) { action in
                            VStack {
                                Text(action.peerName)
                                    .font(.caption2)
                                Text(action.action.rawValue)
                                    .font(.caption)
                                    .bold()
                                if let value = action.value {
                                    Text("\(value)")
                                        .font(.caption)
                                }
                            }
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }

                // Controls
                HStack(spacing: 16) {
                    if collabManager.connectionState == .disconnected {
                        Button("Host Game") {
                            let arSession = ARSession()
                            collabManager.startHosting(arSession: arSession)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Join Game") {
                            let arSession = ARSession()
                            collabManager.startBrowsing(arSession: arSession)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Place Block") {
                            collabManager.sendAction(.placedBlock, value: 1)
                        }
                        .buttonStyle(.borderedProminent)

                        Button("I'm Ready!") {
                            collabManager.sendAction(.ready)
                        }
                        .buttonStyle(.bordered)

                        Button("Celebrate!") {
                            collabManager.sendAction(.celebrate)
                        }
                        .buttonStyle(.bordered)
                        .tint(.yellow)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Collaborative AR")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var statusColor: Color {
        switch collabManager.connectionState {
        case .connected:    return .green
        case .connecting:   return .yellow
        case .searching:    return .orange
        case .disconnected: return .red
        }
    }
}

#endif
