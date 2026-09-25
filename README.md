# Clear the Strait

**He is stuck in the channel. Shove him out.** A one-mechanic arcade game for iPhone: a very round, very self-important blowhard is wedged in a shipping strait, and you tap either side of him in rhythm to rock him loose, pop his speech bubbles before they inflate his ego, and launch him skipping across the water.

[**Free on the App Store**](https://apps.apple.com/app/id6810644510) · optional one-time Blowhard Pack ($1.99) with three more blowhards in their own channels. No ads.

<p>
<img src="fastlane/screenshots/en-US/iPhone%2017%20Pro%20Max-01_Rolling.png" width="220" alt="Rocking him in the channel">
<img src="fastlane/screenshots/en-US/iPhone%2017%20Pro%20Max-03_Tremendous.png" width="220" alt="Tremendous mode">
<img src="fastlane/screenshots/en-US/iPhone%2017%20Pro%20Max-05_Pack.png" width="220" alt="The Blowhard Pack">
</p>

## How it plays

- Tap the side of him that agrees with the way he is already rocking. Timing beats mashing: shoves with his motion score GOOD, GREAT, PERFECT and TREMENDOUS, shoves against it are misses.
- Every good shove works him a little looser. The wedge tightens again if you stop.
- Speech bubbles fly out of him and come home to inflate his ego, which makes him bigger and heavier. Pop them first.
- Rounds last about a minute. After a minute the channel starts to give, and at two and a half minutes he always wriggles free, so no round runs forever.

## How it is built

- **SpriteKit + SwiftUI**, iOS 17+, no image assets: every character is drawn from shapes and paths in `Sources/Game/Blocker.swift`.
- **All the game feel is arithmetic** in `Sources/Game/Rules.swift`: pure functions for combo judging, ego, escape thresholds and the loosening meter, covered by unit tests in `Tests/UnitTests`. The scene is a thin layer that draws the result.
- **StoreKit 2** for the pack (`Sources/Services/PackStore.swift`), with Restore Purchases, and anyone who bought the game while it was paid gets the pack free.
- **Built without a Mac.** XcodeGen `project.yml`, fastlane, and GitHub Actions macOS runners build, test, screenshot, record the App Review video and submit to the App Store. `Store/*.py` drive the App Store Connect API for listing, price and in-app purchase setup.

```sh
brew install xcodegen
xcodegen generate
open ClearTheStrait.xcodeproj
```

## Hire the author

I designed, built and shipped this game myself. **Want an app like it for your business?** I build native iOS apps from prototype to App Store launch, fixed price. [Services and pricing](https://mattbusel.github.io/) · [Email](mailto:mattbusel@gmail.com) · [LinkedIn](https://www.linkedin.com/in/matthewbusel/)
