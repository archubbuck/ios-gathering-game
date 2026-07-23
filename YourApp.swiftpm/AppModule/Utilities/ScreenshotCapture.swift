import SwiftUI
import UIKit

// ---------------------------------------------------------------------------
// ScreenshotCapture — triggered by launching the app with `--screenshots`.
// Renders every major screen with curated mock data, captures each one as
// a PNG into the app's Documents directory, then calls exit(0).
//
// The ci_post_xcodebuild.sh script collects the PNGs from the simulator
// filesystem and exports them as Xcode Cloud artifacts.  From there, a
// GitHub Actions workflow downloads them and posts them to PRs — and the
// same PNGs are suitable for App Store Connect marketing screenshots.
//
// DESIGN: Instead of trying to subclass the real ObservableObject stores
// (which have `private(set)` published properties), each screen is built
// from the component-level views (NameCardView, MatchHeroView, etc.) with
// inline mock data.  This exercises the actual UI components while avoiding
// the store-injection problem entirely.
// ---------------------------------------------------------------------------

// MARK: - Mock Data

private enum ScreenshotMockData {
    static let maleTags: [Tag] = [
        Tag(id: UUID(), slug: "classic", label: "Classic"),
        Tag(id: UUID(), slug: "strong", label: "Strong"),
        Tag(id: UUID(), slug: "literary", label: "Literary"),
    ]
    static let femaleTags: [Tag] = [
        Tag(id: UUID(), slug: "elegant", label: "Elegant"),
        Tag(id: UUID(), slug: "vintage", label: "Vintage"),
        Tag(id: UUID(), slug: "nature", label: "Nature"),
    ]

    static func nameCardTag(from tag: Tag, weight: Double? = nil) -> NameCardTag {
        NameCardTag(id: tag.id, slug: tag.slug, label: tag.label, weight: weight)
    }

    static func nameCard(
        name: String, gender: Gender, origin: String?, meaning: String?,
        tags: [Tag], rank: Int? = nil, trend: PopularityTrend? = nil,
        matchedAt: Date? = nil
    ) -> NameCard {
        NameCard(
            id: UUID(), displayName: name, gender: gender,
            origin: origin, meaning: meaning,
            syllableCount: max(1, name.filter(\.isLetter).count / 2),
            tags: tags.map { nameCardTag(from: $0, weight: Double.random(in: 0.1...1.0)) },
            currentPopularityRank: rank, popularityTrend: trend,
            pronunciationAudioURL: nil, pronunciationIPA: nil,
            matchedAt: matchedAt
        )
    }

    static let deck = Deck(
        id: UUID(), label: "Baby Cole", genderFilter: nil,
        originFilter: [], startingLetterFilter: nil, packFilter: [],
        siblingNames: ["Hannah"], familySurname: "Cole",
        members: [
            DeckMember(id: UUID(), displayName: "You", role: "owner"),
            DeckMember(id: UUID(), displayName: "Morgan", role: "partner"),
        ]
    )

    // --- per-screen cards --------------------------------------------------

    static let swipeTopCard = nameCard(
        name: "Eleanor", gender: .female,
        origin: "Greek", meaning: "Shining light; from Helen, meaning torch or bright one",
        tags: femaleTags, rank: 16, trend: .up
    )
    static let swipeSecondCard = nameCard(
        name: "August", gender: .male,
        origin: "Latin", meaning: "Great, magnificent",
        tags: maleTags, rank: 28, trend: .up
    )

    static let detailCard = swipeTopCard

    static let matchCards: [NameCard] = [
        nameCard(name: "Felix",  gender: .male,   origin: "Latin", meaning: "Happy, fortunate", tags: maleTags,   rank: 33, trend: .up, matchedAt: Date().addingTimeInterval(-3600)),
        nameCard(name: "Clara",  gender: .female, origin: "Latin", meaning: "Bright, clear",    tags: femaleTags, rank: 21, trend: .up, matchedAt: Date().addingTimeInterval(-86400)),
        nameCard(name: "Milo",   gender: .male,   origin: "German", meaning: "Merciful, gentle", tags: maleTags,   rank: 45, trend: .flat, matchedAt: Date().addingTimeInterval(-172800)),
        nameCard(name: "Margot", gender: .female, origin: "French", meaning: "Pearl",             tags: femaleTags, rank: 34, trend: .up, matchedAt: Date().addingTimeInterval(-259200)),
    ]

    static let shortlistCards: [NameCard] = [
        nameCard(name: "Atlas",  gender: .male,   origin: "Greek",  meaning: "Enduring, to carry",     tags: maleTags,   rank: 55, trend: .up),
        nameCard(name: "Sylvie", gender: .female, origin: "French", meaning: "From the forest",          tags: femaleTags, rank: 89, trend: .up),
        nameCard(name: "Orion",  gender: .male,   origin: "Greek",  meaning: "Hunter; constellation",    tags: maleTags,   rank: 47, trend: .flat),
    ]

    static let packs: [NamePack] = [
        NamePack(id: UUID(), slug: "celestial", title: "Celestial Names", description: "Stars, planets, and the cosmos.", themeType: .mythology, coverImageURL: nil, priceCents: 0, currency: "USD", nameCount: 47, unlocked: true),
        NamePack(id: UUID(), slug: "literary",  title: "Literary Heroines", description: "From classic and modern literature.", themeType: .meaning, coverImageURL: nil, priceCents: 0, currency: "USD", nameCount: 62, unlocked: false),
        NamePack(id: UUID(), slug: "nature",    title: "Nature Inspired",  description: "Drawn from the natural world.", themeType: .nature, coverImageURL: nil, priceCents: 0, currency: "USD", nameCount: 81, unlocked: true),
        NamePack(id: UUID(), slug: "vintage",   title: "Vintage Revival",  description: "Classic names making a comeback.", themeType: .style, coverImageURL: nil, priceCents: 0, currency: "USD", nameCount: 55, unlocked: false),
    ]
}

// MARK: - Screenshot Runner

enum ScreenshotScreen: String, CaseIterable {
    case swipe
    case nameDetail
    case matches
    case shortlist
    case marketplace

    var filename: String {
        let idx = String(format: "%02d", ScreenshotScreen.allCases.firstIndex(of: self)! + 1)
        return "\(idx)_\(rawValue).png"
    }
}

struct ScreenshotCatalogView: View {
    @State private var currentIndex = 0
    @StateObject private var themeStore = ThemeStore()

    private let screens = ScreenshotScreen.allCases

    var body: some View {
        Group {
            if currentIndex >= screens.count {
                Color.black.ignoresSafeArea()
            } else {
                currentScreen
                    .environmentObject(themeStore)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                captureNext()
            }
        }
    }

    @ViewBuilder
    private var currentScreen: some View {
        switch screens[currentIndex] {
        case .swipe:        swipeScreenshot
        case .nameDetail:   nameDetailScreenshot
        case .matches:      matchesScreenshot
        case .shortlist:    shortlistScreenshot
        case .marketplace:  marketplaceScreenshot
        }
    }

    // MARK: - Screenshot Screens

        private var screenshotTheme: AppTheme { Palette.blueberry.theme }

    private var swipeScreenshot: some View {
        VStack(spacing: 0) {
            screenshotHeader(chipText: "12 left", tab: .swipe)
            ZStack {
                // Background cards (dimmed, non-interactive)
                NameCardView(card: ScreenshotMockData.swipeSecondCard, isTopCard: false, deck: ScreenshotMockData.deck)
                    .scaleEffect(0.92)
                    .offset(y: 8)
                // Top card
                NameCardView(card: ScreenshotMockData.swipeTopCard, isTopCard: true, deck: ScreenshotMockData.deck)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 20)
            Spacer()
        }
        .background(AppTheme.systemBackground.ignoresSafeArea())
    }

    private var nameDetailScreenshot: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Gradient hero (matches NameCardView's hero section)
                nameDetailHero
                // Attribute rows below the hero
                VStack(alignment: .leading, spacing: 12) {
                    detailRow(label: "Origin", value: ScreenshotMockData.detailCard.origin ?? "—")
                    Divider()
                    detailRow(label: "Meaning", value: ScreenshotMockData.detailCard.meaning ?? "—")
                    Divider()
                    detailRow(label: "Syllables", value: "\(ScreenshotMockData.detailCard.syllableCount ?? 0)")
                    Divider()
                    detailRow(label: "Rank", value: "#\(ScreenshotMockData.detailCard.currentPopularityRank ?? 0)")
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Tags").font(.caption).foregroundStyle(AppTheme.textTertiary)
                        WrapLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                            ForEach(ScreenshotMockData.detailCard.tags) { tag in
                                TagChipView(label: tag.label)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(AppTheme.systemBackground.ignoresSafeArea())
    }

    private var nameDetailHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color.purple, Color.pink],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .frame(height: 260)
            VStack(alignment: .leading, spacing: 4) {
                Text(ScreenshotMockData.detailCard.displayName)
                    .font(.display(42))
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    GenderBadge(gender: ScreenshotMockData.detailCard.gender)
                    if let trend = ScreenshotMockData.detailCard.popularityTrend {
                        Image(systemName: trend.symbolName)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .padding(20)
        }
    }

    private var matchesScreenshot: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenshotHeader(chipText: "4 matches", tab: .matches)

                // Newest match hero
                if let newest = ScreenshotMockData.matchCards.first {
                    MatchHeroView(card: newest, partnerName: "Morgan", theme: screenshotTheme)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                }

                // Match history
                VStack(spacing: 0) {
                    ForEach(ScreenshotMockData.matchCards.dropFirst()) { card in
                        matchRow(card)
                        if card.id != ScreenshotMockData.matchCards.last?.id {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .background(AppTheme.systemBackground.ignoresSafeArea())
    }

    private func matchRow(_ card: NameCard) -> some View {
        HStack(spacing: 12) {
            GradientAvatarView(initial: String(card.displayName.prefix(1)), fill: screenshotTheme.heroGradient, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(card.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let matchedAt = card.matchedAt {
                    Text(matchedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textTertiary)
                }
            }
            Spacer()
            Image(systemName: "heart.fill")
                .font(.caption)
                .foregroundStyle(.pink)
        }
        .padding(.vertical, 10)
    }

    private var shortlistScreenshot: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenshotHeader(chipText: "3 saved", tab: .shortlist)

                LazyVStack(spacing: 12) {
                    ForEach(ScreenshotMockData.shortlistCards) { card in
                        NameCardView(card: card, isTopCard: false, deck: ScreenshotMockData.deck)
                            .frame(height: 200)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
        }
        .background(AppTheme.systemBackground.ignoresSafeArea())
    }

    private var marketplaceScreenshot: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Simplified header for marketplace (not a main tab)
                HStack {
                    Text("Name Packs")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(ScreenshotMockData.packs) { pack in
                        packCard(pack)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .background(AppTheme.systemBackground.ignoresSafeArea())
    }

    private func packCard(_ pack: NamePack) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(height: 90)
                .overlay(alignment: .bottomLeading) {
                    Text(pack.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(8)
                }
            Text(pack.description ?? "")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(2)
            HStack {
                Text("\(pack.nameCount) names")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textTertiary)
                Spacer()
                Text(pack.unlocked ? "✓ Claimed" : "Free")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(pack.unlocked ? .green : screenshotTheme.accent)
            }
        }
        .padding(10)
        .background(AppTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    // MARK: - Shared chrome

    private func screenshotHeader(chipText: String, tab: AppTab) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 34, height: 34)

                Spacer()

                Text(chipText)
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(screenshotTheme.accent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(screenshotTheme.chip, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)

            TabPillsView(selection: .constant(tab), theme: screenshotTheme)
                .padding(.bottom, 4)
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textTertiary)
                .frame(width: 72, alignment: .leading)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    // MARK: - Capture Engine

    private func captureNext() {
        guard currentIndex < screens.count else {
            print("[ScreenshotCapture] All \(screens.count) screenshots captured — exiting.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { exit(0) }
            return
        }

        let screen = screens[currentIndex]
        print("[ScreenshotCapture] Capturing \(screen.rawValue) → \(screen.filename)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                print("[ScreenshotCapture] ERROR: no window found")
                currentIndex += 1
                captureNext()
                return
            }

            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }

            guard let pngData = image.pngData() else {
                print("[ScreenshotCapture] ERROR: PNG conversion failed")
                currentIndex += 1
                captureNext()
                return
            }

            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = docs.appendingPathComponent(screen.filename)

            do {
                try pngData.write(to: fileURL)
                print("[ScreenshotCapture] Saved \(screen.filename) (\(pngData.count) bytes)")
            } catch {
                print("[ScreenshotCapture] ERROR writing \(screen.filename): \(error)")
            }

            currentIndex += 1
            captureNext()
        }
    }
}

// MARK: - Mini Helpers (not extracted to Components/ to keep this file self-contained)

private struct GenderBadge: View {
    let gender: Gender
    var body: some View {
        Text(gender.rawValue.capitalized)
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.white.opacity(0.2), in: Capsule())
    }
}

/// Simplified wrapper layout that flows items horizontally.  Replaces the
/// full FlowLayout component dependency.
private struct WrapLayout: View {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let content: AnyView

    init<C: View>(horizontalSpacing: CGFloat = 6, verticalSpacing: CGFloat = 6, @ViewBuilder content: () -> C) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = AnyView(content())
    }

    var body: some View {
        // Degrade gracefully to an HStack that wraps via the system; full
        // FlowLayout is a Layout protocol implementation that needs iOS 16+
        // and the real component.  For screenshots, HStack + .lineLimit is
        // sufficient for our small curated tag sets.
        HStack(spacing: horizontalSpacing) { content }
    }
}

extension AppTheme {
    static let systemBackground = Color(UIColor.systemBackground)
}
