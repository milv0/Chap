# Chap Brand & Voice

This is the source of truth for who Chap is and how it talks. Every user-facing
word — app UI, notch, menus, alerts, onboarding, website, README, release notes —
follows this document. When copy and this document disagree, fix the copy.
`DESIGN.md` owns colors; this file owns identity and words.

## Who Chap is

**Chap is your chap: a friend that lives in your menu bar and notch.**

It stays out of the way, remembers how you like things, and when you call, it
shows up at once and puts your windows exactly where they belong. Then it steps
back.

## Mascot

The mascot's name is **Chap**. The seal *is* Chap: the friend from "Hi, I'm your
chap." finally has a face. There is no separate character name; in copy, call it
"Chap" (or "Chap the Seal" when the seal needs pointing out, e.g. a feature list).
Never "the mascot" in user-facing text.

Chap is a **baby seal**, drawn as a 24×12 pixel sprite
(`ChapMascot`, three inks: navy outline, white body, blue-gray shade). It lies
on the left of the notch's black strip, always, and tells the Keep Awake story
there. It is decoration, never a
control: it takes no clicks, carries no text, and VoiceOver skips it. Its only
motions are small: a tail flick when you open the notch and now and then (every
7–12 s), and a blink every few seconds. It holds
still when the notch is closed or Reduce Motion is on. Keep it calm: a friend
resting nearby, not a pet asking for attention.

When you press Chap on, the seal dives in: it crouches, hops, splashes into the
water, and pops back up (about 1 s, once). Focus is immersion, and a seal is at
home in the water, but the dive is the moment of starting, not a scene that
stays: afterwards the water is gone and the seal rests in its place, wagging its
tail (slower and drowsy in the last 30 minutes). That wag is the one steady
motion Chap allows, because it means "I'm keeping your Mac awake". Floating,
paddling, or staying under water were tried and cut: they read as a toy or hide
the state. The Focus slot shows the bolt and the time left.

## The name carries both meanings

| Meaning | Where it comes from | What it gives Chap |
|---|---|---|
| **chap** (n., British) | A friendly word for a mate, a good fellow: "he's a nice chap", "alright, chaps?" | The **friend**. Chap is on your side, always close by. |
| **chap** (sound) | The snap of a window landing right where it belongs | The **precision**. One press, and it's done. |

Use both, but never explain the pun at length. One light touch per surface is
enough: a friend who snaps things into place.

## Personality

- **Loyal, not needy.** Always there (menu bar, notch, shortcuts), never nags.
  No badges begging for attention, no upsell, no streaks.
- **Quick, not rushed.** Responds instantly; copy is short and calm.
- **Warm, a little witty.** A friendly aside is welcome; a joke that slows the
  user down is not.
- **Respectful of your stuff.** A good friend doesn't snoop. Chap asks for the
  fewest permissions it can, only when a feature is used, and says plainly what
  it does and doesn't keep. (This is why screen-text recognition was cut: it
  needed Screen Recording for everything on screen.)
- **Humble.** Chap helps; the user is the one getting things done. Credit the
  user, not the app.

## Voice rules

1. **Clarity first, wit second.** The control label says what it does. Wit
   lives in secondary text, empty states, and moments of success.
   - Good: button "Chap off", line above it "Landing soon".
   - Bad: a button whose meaning you can only guess.
2. **Speak like a friend at your side, not a butler or a mascot.** Second person,
   plain words. No "Oops!", no exclamation stacks, no emoji in UI strings.
3. **"Chap" as a verb** is our signature, used sparingly for *starting,
   finishing, or snapping into place*: "Chap on", "Chap off", "Press. Chap. Done."
   Never use it where a plain verb is clearer (e.g. never "Chap this file").
4. **Say what we keep.** When data is involved, one plain sentence: "Nothing is
   recorded or saved." "Stays on your Mac."
5. **Short.** Titles 1–3 words. Notch lines ≤ 4 words. Alerts: one-sentence
   title, one-sentence body, a clear button.
6. **English UI, Korean-friendly.** UI stays English; avoid idioms a non-native
   reader can't decode ("wind down" was replaced by "Chap off" for this reason).
   The in-app Q&A keeps Korean and English versions in sync.

## Signature lines (approved)

| Surface | Line |
|---|---|
| Positioning | Your chap in the menu bar. |
| Hero | Open anything. Chap. Centered. |
| Sign-off / CTA | Press. Chap. Done. |
| Welcome | Hi, I'm your chap. |
| Welcome subtitle | Your friend in the menu bar. Tell me what you open most, and I'll bring it to the center of your screen. |
| About | Your chap in the menu bar — always close, never in the way. |
| Mascot | Chap the Seal (the seal is Chap) |
| Focus (idle) | Chap on (in the center of the Focus ring) |
| Focus (stop) | Chap off |
| Focus (running) | Fully charged → In the zone → Final stretch → Landing soon |

## Do / Don't

| Do | Don't |
|---|---|
| "Hi, I'm your chap." | "Welcome to the ultimate productivity suite!" |
| "Nothing is recorded or saved." | "Your privacy is our top priority!!" |
| "No recent downloads" | "Oops, nothing here yet 😢" |
| "Chap off" (with tooltip "Turn off Keep Mac Awake") | "Wind down", "Terminate session" |
| One friendly aside per screen | A pun in every label |

## Checklist for new copy

- Does the control label say plainly what happens?
- Is any wit in secondary text, not the action itself?
- Would a friend say it this way?
- If data or permissions are involved, did we say what we keep?
- Is it short enough for the notch (≤ 4 words per line)?
- Is the Korean Q&A updated alongside the English?
