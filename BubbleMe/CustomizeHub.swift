import SwiftUI

struct CustomizeHub: View {
    @ObservedObject var profile: ProfileManager
    @StateObject private var shop = ShopStore()
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Label("\(profile.bubbles)", systemImage: "circle.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Palette.aqua)
                    Spacer()
                    Text(shop.message)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Picker("", selection: $tab) {
                    Text("Shooter").tag(0)
                    Text("Bubbles").tag(1)
                    Text("Scene").tag(2)
                    Text("Buy").tag(3)
                }
                .pickerStyle(.segmented)
                .padding(16)

                TabView(selection: $tab) {
                    shooterPage.tag(0)
                    colorPage.tag(1)
                    scenePage.tag(2)
                    buyPage.tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(Palette.bg.ignoresSafeArea())
            .navigationTitle("Customize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var shooterPage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(ShooterKind.allCases) { kind in
                    cosmeticRow(
                        emoji: kind.emoji,
                        title: kind.title,
                        blurb: kind.blurb,
                        price: kind.price,
                        equipped: profile.shooter == kind,
                        owned: profile.owns(shooter: kind)
                    ) {
                        profile.buyOrEquip(shooter: kind)
                    }
                }
            }
            .padding(16)
        }
    }

    private var colorPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Palette").font(.display(18))
                ForEach(ColorPack.allCases) { pack in
                    Button {
                        profile.buyOrEquip(palette: pack)
                    } label: {
                        HStack {
                            HStack(spacing: 4) {
                                ForEach(Array(pack.swatches.enumerated()), id: \.offset) { _, c in
                                    Circle().fill(c).frame(width: 16, height: 16)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pack.title).font(.display(16))
                                Text(pack.price == 0 ? "Free" : "\(pack.price) Bubbles")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            badge(equipped: profile.palette == pack, owned: profile.owns(palette: pack), price: pack.price)
                        }
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .foregroundStyle(Palette.fg)
                }
                Text("Texture").font(.display(18)).padding(.top, 8)
                ForEach(BubbleStyle.allCases) { style in
                    cosmeticRow(
                        emoji: style == .solid ? "●" : style == .matte ? "◉" : "◇",
                        title: style.title,
                        blurb: style == .solid ? "Glossy candy." : style == .matte ? "Soft, no shine." : "Mirror metal.",
                        price: style.price,
                        equipped: profile.style == style,
                        owned: profile.owns(style: style)
                    ) {
                        profile.buyOrEquip(style: style)
                    }
                }
            }
            .padding(16)
        }
    }

    private var scenePage: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(PlayBackground.allCases) { bg in
                    Button {
                        profile.buyOrEquip(background: bg)
                    } label: {
                        HStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(uiColor: bg.top), Color(uiColor: bg.bottom)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 56, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(bg.title).font(.display(16))
                                Text(bg.price == 0 ? "Free" : "\(bg.price) Bubbles")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            badge(equipped: profile.background == bg, owned: profile.owns(background: bg), price: bg.price)
                        }
                        .padding(12)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .foregroundStyle(Palette.fg)
                }
            }
            .padding(16)
        }
    }

    private var buyPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Buy Bubbles")
                    .font(.display(22, weight: .bold))
                Text("Apple In-App Purchase — not Stripe. Bigger packs cost less per Bubble.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Palette.muted)
                ForEach(BubblePack.allCases) { pack in
                    Button {
                        Task { await shop.buy(pack, into: profile) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(pack.title).font(.display(18))
                                Text("\(pack.bubbles) Bubbles · \(pack.perHundred)")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Palette.muted)
                            }
                            Spacer()
                            Text(pack.displayPrice)
                                .font(.display(16, weight: .bold))
                                .padding(.horizontal, 12)
                                .frame(height: 36)
                                .background(Palette.accent, in: Capsule())
                        }
                        .padding(14)
                        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .foregroundStyle(Palette.fg)
                    .disabled(shop.busy)
                }
            }
            .padding(16)
        }
    }

    private func cosmeticRow(emoji: String, title: String, blurb: String, price: Int, equipped: Bool, owned: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji).font(.system(size: 28)).frame(width: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.display(16))
                    Text(blurb)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Palette.muted)
                }
                Spacer()
                badge(equipped: equipped, owned: owned, price: price)
            }
            .padding(12)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .foregroundStyle(Palette.fg)
    }

    private func badge(equipped: Bool, owned: Bool, price: Int) -> some View {
        Group {
            if equipped {
                Text("On").font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Palette.aqua.opacity(0.25), in: Capsule())
            } else if owned {
                Text("Use").font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Palette.surface2, in: Capsule())
            } else if price == 0 {
                Text("Free").font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Palette.surface2, in: Capsule())
            } else {
                Text("\(price)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, 10).frame(height: 28)
                    .background(Palette.accent.opacity(0.3), in: Capsule())
            }
        }
    }
}
