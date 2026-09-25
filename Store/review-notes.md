# App Review notes

Pasted into the "Notes" field of the App Review Information section. Also
supplied programmatically by `Store/listing.py review-details`.

---

No account, login or network connection is required. Tap PLAY and the game
starts immediately.

HOW TO PLAY: choose a character in the row above PLAY (the first is free),
then tap PLAY. Tap the left side of the character to shove him right, the right
side to shove him left. Shoving in time with the way he is already rocking
builds a combo. Speech bubbles drift away from him and return; tapping a bubble
pops it. When enough momentum accumulates he is launched out of the channel and
the result screen appears. A round lasts about 45 to 120 seconds.

ABOUT THE CONTENT

This is an original satirical cartoon in the tradition of the editorial
cartoon: an exaggerated, extremely round caricature of a generic self-important
public figure who has become stuck in a fictional waterway.

Specifically, and by design:

- The character is not named anywhere in the app, its metadata, its code or its
  marketing. He is a comic archetype, not a portrait of a specific individual.
- The setting is fictional and unnamed. It is referred to only as "the channel"
  or "the strait". No real country, city, waterway, border, map or geographic
  feature appears or is referenced.
- No real conflict, war, military operation, political event, election or
  organisation appears or is referenced.
- No flags, national symbols, insignia or military vessels appear. The only
  vessels are generic toy container ships.
- Every line of dialogue is written for this game. Nothing is a quotation of
  anything any real person has said, and the app never presents any line as a
  real quotation.
- There is no violence, injury, blood, weaponry or peril of any kind. The
  entire interaction is pushing an oversized cartoon ball out of the way, in
  the manner of a beach ball. The character is unharmed throughout and is
  cheerful about the whole thing.

The humour is physical and absurd: a very round man is stuck, he is pleased
with himself about it, and being pleased with himself makes him harder to move.

AGE RATING: submitted as 4+. There is no violence, no profanity, no suggestive
content, no gambling, no user-generated content, no chat, no web access and no
advertising.

PRIVACY: no data of any kind is collected. There is no analytics, no crash
reporting, no advertising identifier and no server belonging to this app. Two
personal-best numbers, the chosen character and whether the pack is unlocked
are stored on the device in UserDefaults, declared in the privacy manifest
under CA92.1. There is no Game Center in this version.

MONETISATION (new in 1.1): the game is now free, with no advertising. One
optional non-consumable in-app purchase, "The Blowhard Pack"
(com.mattbusel.clearthestrait.pack1), adds three more playable characters: The
Windbag, The Tycoon and The Mayor. Each is the same generic unnamed archetype
treatment as the original (no real person is portrayed), in his own fictional
channel with a small rule twist.

HOW TO TEST THE PURCHASE: on the title screen tap GET THE BLOWHARD PACK, or tap
any character with a lock in the row above PLAY. The pack screen shows the
three characters, UNLOCK (buys the pack) and RESTORE PURCHASES. After buying,
the three characters become selectable; pick one and tap PLAY. The base game is
fully playable without buying anything.

People who bought the app when it was paid (builds 1 and 2) receive the pack
automatically, checked with StoreKit's AppTransaction. This only applies in the
production App Store, so in the review sandbox the purchase is shown normally.
