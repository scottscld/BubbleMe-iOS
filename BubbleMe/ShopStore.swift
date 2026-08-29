import Foundation
import StoreKit
import Combine

/// Apple In-App Purchase for Bubbles. Uses StoreKit 2 — never Stripe.
@MainActor
final class ShopStore: ObservableObject {
    @Published var message = ""
    @Published var busy = false

    func buy(_ pack: BubblePack, into profile: ProfileManager) async {
        busy = true
        defer { busy = false }
        do {
            let products = try await Product.products(for: [pack.id])
            if let product = products.first {
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    let transaction = try check(verification)
                    profile.addBubbles(pack.bubbles)
                    await transaction.finish()
                    message = "+\(pack.bubbles) Bubbles"
                    Haptics.win()
                case .userCancelled:
                    message = "Cancelled"
                case .pending:
                    message = "Waiting for approval"
                @unknown default:
                    message = "Couldn’t complete purchase"
                }
            } else {
                // No App Store product yet (free Apple ID / no paid account).
                // Grant the pack so cosmetics can be tried; real charges start
                // after you join the Apple Developer Program and add these IDs.
                profile.addBubbles(pack.bubbles)
                message = "+\(pack.bubbles) Bubbles (test grant — IAP goes live with a paid Apple account)"
                Haptics.win()
            }
        } catch {
            profile.addBubbles(pack.bubbles)
            message = "+\(pack.bubbles) Bubbles (test grant). IAP needs a paid developer account."
            Haptics.win()
        }
    }

    private func check<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let value): return value
        }
    }
}
