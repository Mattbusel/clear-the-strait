import SpriteKit

/// Who is stuck, and where.
///
/// Every blowhard is the same joke told about a different *type*: a generic,
/// unnamed, extremely round figure of self-importance. None of them is a
/// portrait of anybody. They are the stock characters of the editorial cartoon
/// (the windbag, the tycoon, the small-town mayor) and every line they say is
/// written for this game.
///
/// The first one is free. The other three are the Blowhard Pack.
struct Blowhard: Identifiable, Equatable {
    enum ID: String, CaseIterable {
        case blowhard
        case windbag
        case tycoon
        case mayor
    }

    /// What sits on top of the sphere.
    enum Top: Equatable {
        /// The confident swoop.
        case swoop
        /// Two white tufts and round spectacles.
        case tufts
        /// A tall hat and a monocle.
        case topHat
        /// Bald, with a shine and an enormous moustache.
        case bald
    }

    /// What hangs down the front.
    enum Neck: Equatable {
        case longTie
        case bowTie
        case waistcoat
        case sash
    }

    let id: ID
    let name: String
    let channel: String
    let blurb: String
    let twistLine: String
    let isPack: Bool

    let suit: SKColor
    let suitEdge: SKColor
    let shirt: SKColor
    let accent: SKColor
    let hair: SKColor
    let hairEdge: SKColor
    let top: Top
    let neck: Neck

    let theme: Theme
    let twist: Twist
    let quotes: [String]

    static func == (a: Blowhard, b: Blowhard) -> Bool { a.id == b.id }

    static let all: [Blowhard] = [.blowhard, .windbag, .tycoon, .mayor]
    static var pack: [Blowhard] { all.filter(\.isPack) }

    static func with(_ id: ID) -> Blowhard {
        all.first { $0.id == id } ?? .blowhard
    }

    func randomQuote() -> String {
        quotes.randomElement() ?? "NOBODY BLOCKS A CHANNEL BETTER THAN ME!"
    }
}

/// The water, the land and the light for one channel.
struct Theme {
    let water: SKColor
    let deepWater: SKColor
    let shallow: SKColor
    let foam: SKColor
    let land: SKColor
    let sand: SKColor
    let buoy: SKColor
    /// A dark wash over everything, for the night canal. Zero for daylight.
    let dusk: CGFloat

    static let day = Theme(
        water: Palette.water, deepWater: Palette.deepWater, shallow: Palette.shallow,
        foam: Palette.foam, land: Palette.land, sand: Palette.sand,
        buoy: Palette.hullAlt, dusk: 0
    )
}

private func rgb(_ r: Double, _ g: Double, _ b: Double) -> SKColor {
    SKColor(red: r, green: g, blue: b, alpha: 1)
}

extension Blowhard {
    /// The original. Free, and unchanged.
    static let blowhard = Blowhard(
        id: .blowhard,
        name: "The Blowhard",
        channel: "The Channel",
        blurb: "Where it all started. He is stuck and delighted about it.",
        twistLine: "The classic round.",
        isPack: false,
        suit: Palette.suit, suitEdge: Palette.suitEdge, shirt: Palette.shirt,
        accent: Palette.tie, hair: Palette.hair, hairEdge: Palette.hairEdge,
        top: .swoop, neck: .longTie,
        theme: .day,
        twist: .standard,
        quotes: Quotes.lines
    )

    /// Talks constantly. Each compliment is smaller, but there are far more.
    static let windbag = Blowhard(
        id: .windbag,
        name: "The Windbag",
        channel: "The Fog Channel",
        blurb: "Has been speaking since breakfast. Will be speaking at dinner.",
        twistLine: "Twice the bubbles, half the ego each. Pop fast.",
        isPack: true,
        suit: rgb(0.36, 0.38, 0.44), suitEdge: rgb(0.22, 0.23, 0.28), shirt: rgb(0.97, 0.96, 0.92),
        accent: rgb(0.52, 0.18, 0.46), hair: rgb(0.95, 0.95, 0.97), hairEdge: rgb(0.72, 0.74, 0.80),
        top: .tufts, neck: .bowTie,
        theme: Theme(
            water: rgb(0.42, 0.56, 0.64), deepWater: rgb(0.26, 0.38, 0.47), shallow: rgb(0.66, 0.76, 0.80),
            foam: rgb(0.93, 0.95, 0.96), land: rgb(0.55, 0.64, 0.56), sand: rgb(0.86, 0.85, 0.78),
            buoy: rgb(0.95, 0.55, 0.25), dusk: 0
        ),
        twist: Twist(bubbleInterval: 0.55, egoGain: 0.55, popLoss: 0.7),
        quotes: [
            "AS I WAS SAYING, FOR FOUR HOURS...",
            "I YIELD MY TIME. TO MYSELF.",
            "LET ME BE BRIEF. PART ONE.",
            "POINT OF ORDER: I AM THE POINT!",
            "I HAVE A FEW REMARKS. NINETY OF THEM.",
            "WHERE WAS I? OH YES. ME.",
            "IN CONCLUSION, AND ALSO IN ADDITION...",
            "I MOVE THAT EVERYONE LISTEN TO ME!",
            "SECONDLY, AND I CANNOT STRESS THIS...",
            "I WILL NOW READ THE PHONE BOOK!",
            "PLEASE HOLD YOUR APPLAUSE. FOREVER.",
            "MY THIRTY SECOND SPEECH, CHAPTER NINE!",
        ]
    )

    /// Heavier to shift, but when he goes, he goes a very long way.
    static let tycoon = Blowhard(
        id: .tycoon,
        name: "The Tycoon",
        channel: "The Marina",
        blurb: "Bought the channel. Then got stuck in it. Refuses to discuss this.",
        twistLine: "Harder to budge. Launches half as far again.",
        isPack: true,
        suit: rgb(0.13, 0.13, 0.16), suitEdge: rgb(0.05, 0.05, 0.07), shirt: rgb(0.99, 0.98, 0.95),
        accent: rgb(0.93, 0.72, 0.20), hair: rgb(0.10, 0.10, 0.12), hairEdge: rgb(0.02, 0.02, 0.03),
        top: .topHat, neck: .waistcoat,
        theme: Theme(
            water: rgb(0.10, 0.62, 0.66), deepWater: rgb(0.04, 0.44, 0.52), shallow: rgb(0.42, 0.85, 0.82),
            foam: rgb(0.93, 0.99, 0.98), land: rgb(0.98, 0.86, 0.62), sand: rgb(1.00, 0.95, 0.80),
            buoy: rgb(0.93, 0.72, 0.20), dusk: 0
        ),
        twist: Twist(escape: 1.12, launch: 1.5),
        quotes: [
            "I OWN THIS WATER. PROBABLY.",
            "HAVE THE YACHT GO AROUND!",
            "I'M NOT STUCK. I'M INVESTED.",
            "PUT THE WHOLE CHANNEL ON MY TAB!",
            "I'LL BUY A BIGGER CHANNEL!",
            "MY MONOCLE HAS A MONOCLE!",
            "THIS WEDGE IS AN ASSET!",
            "SHIPS? I'LL BUY THE SHIPS!",
            "TIME IS MONEY. I'M VERY RICH.",
            "MY ACCOUNTANT SAYS I'M FLOATING!",
            "I DON'T SQUEEZE. I ACQUIRE.",
            "NAME A BRIDGE AFTER ME. ANY BRIDGE.",
        ]
    )

    /// His promises come home fast, but popping one really stings.
    static let mayor = Blowhard(
        id: .mayor,
        name: "The Mayor",
        channel: "The Night Canal",
        blurb: "Here to cut a ribbon. Currently wedged in a canal at midnight.",
        twistLine: "Promises return fast. Popping one hits hard.",
        isPack: true,
        suit: rgb(0.16, 0.40, 0.30), suitEdge: rgb(0.08, 0.24, 0.17), shirt: rgb(0.98, 0.97, 0.94),
        accent: rgb(0.86, 0.14, 0.20), hair: rgb(0.40, 0.24, 0.14), hairEdge: rgb(0.24, 0.13, 0.07),
        top: .bald, neck: .sash,
        theme: Theme(
            water: rgb(0.09, 0.20, 0.38), deepWater: rgb(0.05, 0.11, 0.25), shallow: rgb(0.28, 0.42, 0.66),
            foam: rgb(0.86, 0.90, 1.00), land: rgb(0.16, 0.30, 0.26), sand: rgb(0.42, 0.46, 0.40),
            buoy: rgb(1.00, 0.82, 0.36), dusk: 0.16
        ),
        twist: Twist(popLoss: 1.6, bubbleReturn: 0.72),
        quotes: [
            "VOTE FOR ME, THE CANAL!",
            "I PROMISE A BIGGER CANAL!",
            "RIBBON CUTTING AT NOON. I'M THE RIBBON.",
            "FREE PARKING FOR EVERY SHIP!",
            "A STATUE OF ME IN EVERY PARK!",
            "I'VE KISSED EVERY BABY. TWICE.",
            "THIS CANAL IS OPEN FOR BUSINESS!",
            "MY SASH SAYS MAYOR. SO I AM.",
            "ELECT ME AND I'LL UNSTICK MYSELF!",
            "NEW POTHOLES? I'LL NAME THEM TOO!",
            "THE KEY TO THE CITY? I AM THE KEY!",
            "SHAKE MY HAND. BOTH OF THEM.",
        ]
    )
}
