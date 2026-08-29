import Foundation
import MultipeerConnectivity
import SwiftUI

/// Nearby friend battle over Wi‑Fi / Bluetooth. Same room code → same seeded board.
/// Host advertises `BM-XXXX`. Joiner browses for that code. Shots stay local;
/// ZigZag / Mirror / Shuffle and score / win travel to the opponent.
final class FriendBattleLink: NSObject, ObservableObject {
    static let service = "bubbleme-btl"

    @Published var connected = false
    @Published var status = "Waiting for a friend…"
    @Published var opponentName = "Friend"
    @Published var opponentScore = 0
    @Published var opponentWon = false

    let code: String
    let hosting: Bool
    private let peer: MCPeerID
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?

    var onPower: ((BattlePower) -> Void)?
    var onConnected: (() -> Void)?
    var onScore: ((Int) -> Void)?
    var onOpponentWin: (() -> Void)?
    var onDropped: (() -> Void)?

    init(code: String, hosting: Bool, name: String) {
        self.code = code.uppercased()
        self.hosting = hosting
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let display = trimmed.isEmpty ? "Player" : String(trimmed.prefix(24))
        self.peer = MCPeerID(displayName: display)
        super.init()
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    func start() {
        if hosting {
            status = "Share \(code) — waiting nearby…"
            let adv = MCNearbyServiceAdvertiser(
                peer: peer,
                discoveryInfo: ["code": code],
                serviceType: Self.service
            )
            adv.delegate = self
            adv.startAdvertisingPeer()
            advertiser = adv
        } else {
            status = "Looking for \(code)…"
            let br = MCNearbyServiceBrowser(peer: peer, serviceType: Self.service)
            br.delegate = self
            br.startBrowsingForPeers()
            browser = br
        }
    }

    func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
        advertiser = nil
        browser = nil
    }

    func sendPower(_ p: BattlePower) {
        send(["t": "power", "id": p.rawValue])
    }

    func sendScore(_ n: Int, over: String?) {
        var payload: [String: String] = ["t": "score", "n": String(n)]
        if let over { payload["over"] = over }
        send(payload)
    }

    private func send(_ dict: [String: String]) {
        guard !session.connectedPeers.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: dict) else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    deinit { stop() }
}

extension FriendBattleLink: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                self.connected = true
                self.opponentName = peerID.displayName
                self.status = "Dueling \(peerID.displayName)"
                self.onConnected?()
            case .connecting:
                self.status = "Connecting…"
            default:
                if self.connected {
                    self.status = "Friend dropped — CPU takes over"
                    self.connected = false
                    self.onDropped?()
                }
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String] else { return }
        DispatchQueue.main.async {
            switch obj["t"] {
            case "power":
                if let raw = obj["id"], let p = BattlePower(rawValue: raw) {
                    self.onPower?(p)
                }
            case "score":
                self.opponentScore = Int(obj["n"] ?? "0") ?? 0
                self.onScore?(self.opponentScore)
                if obj["over"] == "win" {
                    self.opponentWon = true
                    self.onOpponentWin?()
                }
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName name: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension FriendBattleLink: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension FriendBattleLink: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        guard (info?["code"] ?? "").uppercased() == code else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 12)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
}

enum RoomCode {
    static func make() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<4).map { _ in alphabet.randomElement()! })
    }

    static func seed(_ code: String) -> Int {
        var hash = 2166136261
        for b in code.uppercased().utf8 {
            hash ^= Int(b)
            hash = hash &* 16777619
        }
        return abs(hash)
    }
}
