# App Review notes

Pasted into the "Notes" field of the App Review Information section. Also
supplied programmatically by `Store/listing.py review-details`.

---

No account, login or network connection is needed to play. Tap PLAY and the game starts.

HOW TO PLAY: tap the left side of the character to shove him right, the right side to shove him left. Shoving in time with his rocking builds a combo. Speech bubbles drift away and come back; tap one to pop it. With enough momentum he launches and the result screen appears. A round lasts 45 to 120 seconds and always ends (after 150 s he comes free by himself).

NEW IN 1.2 (title screen, top to bottom)
- CLUB (crown, top left): the Strait Club subscription screen.
- Trophy (top right): Game Center leaderboards (Longest Launch, Fastest Clear, Daily Strait). Medals report as Game Center achievements.
- Medal pill (top right): the Locker with medals, records, trails, shop, and Settings (daily reminder toggle, Game Center achievements).
- DAILY STRAIT card: one fixed challenge per day computed from the date; one try a day, retries optional.
- SEASON card: this month's ten Club Season goals. Goals 1 to 3 are open to everyone; 4 to 10 need the Strait Club.
- Widgets: Daily Strait and Daily Streak (Home and Lock Screen), a Control Center control and a Siri shortcut ("Play the Daily Strait"), all opening the app on the daily.
- The daily reminder is a local notification, offered only after a Daily Strait win or in Locker > Settings. Never asked on launch.

STRAIT CLUB (auto-renewable subscription, group "Strait Club")
- Strait Club Monthly $2.99 per month; Strait Club Yearly $14.99 per year with a one-week free trial for new subscribers.
- To test: tap CLUB on the title screen. The screen lists every benefit, both plans with price and period, the trial terms, auto-renew terms, Terms of Use (Apple standard EULA) and Privacy Policy links, Restore Purchases and Redeem Code. After subscribing it shows the plan, renewal date and Manage Subscription.
- While subscribed: the three extra characters, all ten season goals, unlimited Daily Strait retries and postcards, three Streak Shields a month, every trail and app icon. Joining or leaving never removes anything bought.

OTHER IN-APP PURCHASES (StoreKit 2; Locker > Shop lists all with prices and Restore Purchases)
- 3 Daily Retries, 2 Streak Shields, 3 Postcards: consumables, $0.99 each.
- Trail Pack, Icon Pack: non-consumables, $0.99 each.
- The Blowhard Pack: existing non-consumable, unchanged.
No randomized rewards or loot boxes; every item says exactly what it gives.

ABOUT THE CONTENT: an original satirical cartoon of generic, unnamed, round self-important figures stuck in fictional waterways. No real person, country, place or event appears or is referenced; no flags or military vessels; every line is written for this game and none is presented as a real quotation. No violence: the whole interaction is pushing a cartoon ball out of the way.

PRIVACY: no data is collected. No analytics, crash reporting, advertising identifier or server. Progress is stored on the device (UserDefaults, privacy manifest CA92.1) and in an app group shared with the widgets. Game Center is Apple's own service and is optional.
