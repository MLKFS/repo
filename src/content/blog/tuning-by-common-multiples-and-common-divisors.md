---
title: "Tuning by Common Multiples and Common Divisors"
subtitle: "Two experiments in treating six guitar strings as one resonant system."
description: "An experimental look at guitar tuning: keeping EADGBE within a few cents of equal temperament while building deliberate integer relationships between the open strings — coincident harmonics for electric feedback, and a shared subharmonic as a mathematical extension."
pubDate: 2026-08-20
author: "Ege Batuhan Akgül"
organization: "MLKFS"
---

Standard guitar tuning gives us E–A–D–G–B–E, but the frequencies underneath those names are compromises. In 12-tone equal temperament, only the octave is a pure whole-number ratio; every other interval is displaced by a few cents from the simple ratios that a vibrating string naturally produces.

What happens if we keep EADGBE as the identity and playable geometry of the instrument, but stop treating equal temperament as the only possible target for the six open strings?

Two opposite constructions emerge. One searches upward, for harmonics the strings can share. The other searches downward, for a frequency the strings could all be harmonics *of*. Neither requires moving any string more than about four cents — less than most players ever tune to in the first place.

Before going further, one honest disclaimer: none of the ideas below are individually new, and the names we use for them here — "common-multiple tuning", "common-divisor tuning" — are our labels, not established terminology. What might be mildly interesting is the framing: treating the six open strings as one global optimization problem, with an explicit error budget in cents and an explicit preference for physically meaningful harmonics. We will come back to what already exists at the end.

---

## What is established

A (nearly) ideal string vibrating at fundamental frequency `f` also vibrates at `2f, 3f, 4f, …` — the harmonic series. When two strings with fundamentals `f₁` and `f₂` satisfy

> `n · f₁ = m · f₂`  for small integers `n, m`

some of their partials land on exactly the same frequency. This coincidence-of-partials view of consonance goes back to [Helmholtz](https://archive.org/details/onsensationsofto00helmrich), and it is the reason simple ratios sound "locked in": the third harmonic of a low E and the second harmonic of the B a fifth above it are the same note.

Guitarists already exploit this every time they tune with the fifth- and seventh-fret harmonics. That method silently produces whole-number ratios rather than equal-tempered intervals — which is exactly why it drifts audibly out of tune with a keyboard. Tune the B string to the seventh-fret harmonic of the low E and it lands about two cents sharp of equal temperament, because `3:1` is a pure twelfth and the equal-tempered twelfth is not pure.

Two more established facts constrain everything below:

- **Real strings are slightly inharmonic.** Stiffness pushes the actual partials sharp of the ideal `n·f`, and the shift grows roughly with `n²` ([the stiff-string wave equation](https://arxiv.org/abs/1603.05516)). On a guitar this smearing reaches whole cents somewhere around the 8th–15th partial. Any scheme that depends on the 29th harmonic of a string landing somewhere exact is fiction: by that order, the partial isn't where the ideal math says it is, and it carries almost no energy anyway.
- **Sympathetic resonance between guitar strings is real but weak.** Strings couple through the bridge and body; an undamped string audibly rings when another string feeds its frequencies. Whether that coupling — or the feedback loop of an amplified guitar — behaves *measurably differently* under the tunings below is precisely the open question, not something we get to assume.

---

## Experiment 1: common multiples (the feedback tuning)

On an electric guitar under gain, feedback settles at frequencies where the loop — string, pickup, amplifier, speaker, air, body, string — has enough gain to sustain itself. Open strings that share a partial offer the same frequency several paths back into the system. The hypothesis, and it is only a hypothesis: a tuning with deliberately coincident low-order partials gives feedback more places to lock, and changes how the instrument settles when everything rings.

The construction starts from the two E strings, kept exactly two octaves apart, and derives everything else as a whole-number ratio of the low E:

| String | Ratio to E2 | Frequency | Offset from 12-TET | Lowest shared partial |
|---|---|---|---|---|
| E2 | 1 | 82.41 Hz | 0.0 ¢ | anchor |
| A2 | 4/3 | 109.88 Hz | −2.0 ¢ | 3×A = open E4 (329.6 Hz) |
| D3 | 16/9 | 146.50 Hz | −3.9 ¢ | 3×D = 4×A (439.5 Hz) |
| G3 | 19/8 | 195.72 Hz | −2.5 ¢ | 8×G = 19×E2 (1565.7 Hz) |
| B3 | 3 | 247.22 Hz | +2.0 ¢ | B *is* the 3rd harmonic of E2 |
| E4 | 4 | 329.63 Hz | 0.0 ¢ | anchor |

No string moves more than 3.9 cents. The offsets are pure interval arithmetic, so they apply unchanged to a half-step-down E♭ tuning.

Some of what falls out is pleasingly low-order. The open B string sits exactly on the third harmonic of the low E, and `4×B = 3×E4` at 988.9 Hz, so the two E strings and the B share partials all the way up. The third harmonic of the A string is the open high E itself. The D and A strings meet at 439.5 Hz.

Here is the honest part: **five of these six strings are just the old harmonics tuning.** Ratios of 4/3, 16/9, 3 and 4 are exactly what the fifth- and seventh-fret harmonic method produces. The only deliberate choice in the table is G. The harmonics method would give G = 64/27 of E2, which lands 5.9 cents flat — the famous weak spot of tuning by harmonics. Choosing `G = 19/8 · E2` instead keeps G within 2.5 cents *and* pins its 8th harmonic to the 19th harmonic of the low E at about 1.6 kHz — high, but still within the range where a guitar, its pickups and an amplifier carry meaningful energy.

An earlier draft of this construction related G to B through `29·G = 23·B`, which is numerically closer to equal temperament (+0.65 ¢). We dropped it. The coincidence it buys lives at 5.7 kHz on the 29th partial of the G string — an order at which string stiffness has already shifted the real partial by more than the tuning precision being optimized, and at which almost no energy remains. A rational relation that only exists in the 29th harmonic exists on paper, not on a guitar. That trade — accept two extra cents of offset in exchange for coincidences the instrument can physically express — is the whole design principle here.

Whether any of this changes feedback behavior in practice is an experiment, not a result. We are not claiming it works. We are claiming it is cheap to try.

---

## Experiment 2: common divisors (the subharmonic construction)

Now reverse the direction. Instead of asking where the harmonics meet *above* the strings, ask whether all six fundamentals can be written as integer multiples of a single frequency *below* them:

> `fᵢ = nᵢ · F₀`  for integers `nᵢ`

This is where a "greatest common divisor" analogy suggests itself — and it is worth being precise about the word. Equal-tempered frequencies have irrational ratios, so no common divisor exists at all. The moment you nudge the strings onto whole-number ratios, a common divisor exists *automatically*: the tuning in the table above already has one, at `F₀ = E2/72 ≈ 1.14 Hz`, with the strings sitting at multiples 72, 96, 128, 171, 216 and 288.

That reveals something the two-experiments framing slightly hides: **the two constructions are mathematically the same thing viewed from opposite ends.** Six strings share a common subharmonic exactly when every pair of strings shares coincident partials. The common-multiple view and the common-divisor view describe one family of tunings; the only physical question is whether the coincidences occur at orders low enough to matter.

Treated as a question in Diophantine approximation — how coarse can `F₀` be while every string stays within ±5 cents of EADGBE? — the answer has a clean shape. Writing `F₀ = E2/q` and choosing the nearest integer multiple for each string:

| q | F₀ | Worst string error |
|---|---|---|
| 18 | 4.58 Hz | 7.6 ¢ |
| 24 | 3.43 Hz | 9.6 ¢ (D string fails) |
| 42 | 1.96 Hz | 3.8 ¢ |
| 69 | 1.19 Hz | 2.0 ¢ |
| 72 | 1.14 Hz | 3.9 ¢ (= the tuning above) |
| 206 | 0.40 Hz | 0.85 ¢ |

The elbow sits around `q ≈ 42–72`: below that, some string (usually D or G) cannot stay within five cents; beyond `q = 69` the improvement stalls near two cents for a long stretch, because the pure fourth and pure twelfth that pin the A and B strings are themselves 1.955 cents from equal temperament. Finer subdivision buys almost nothing until the integers grow past 150 — deep into physically meaningless territory.

And here is where conservatism is required. A shared period of 1–3 Hz is infrasonic. It is not heard as a pitch: virtual pitch — the "missing fundamental" the ear reconstructs from upper partials — operates when the implied fundamental is in the audible range, not at 1.14 Hz. Nor does the shared period do anything mechanical on its own: the strings are not phase-locked, and real inharmonicity breaks the exact periodicity anyway. Any genuine acoustic consequence of a common subharmonic is carried entirely by the coincident audible partials — which is Experiment 1 again.

So the common-divisor construction should be read as what it is: a coordinate system, not a claim. It is an elegant way to *parameterize* the family of near-EADGBE rational tunings and to see the trade-off between integer size and tuning error. It earns a place in the mathematics. It does not earn a claim about sound.

---

## What already exists

Almost every ingredient here has a literature. Coincident partials as the basis of consonance is [Helmholtz](https://archive.org/details/onsensationsofto00helmrich); tuning toward aligned partials, including for non-standard spectra, is developed at length in William Sethares' [*Tuning, Timbre, Spectrum, Scale*](https://sethares.engr.wisc.edu/ttss.html) and his work on [adaptive tunings](https://sethares.engr.wisc.edu/papers/adaptun.html). Just-intonation guitars, microtonal fretwork, and "sweetened" tunings that offset open strings by a few cents are established practice, and commercial systems like Buzz Feiten and True Temperament already ship cent-level corrections — though those aim at making fretted notes *more* equal-tempered, roughly the opposite goal. Piano tuners have always tuned to the instrument's actual partials rather than ideal ones; [entropy-based tuning](https://arxiv.org/abs/1203.5101) formalizes exactly that.

What we have not seen framed this way is the small, specific thing this post does: take the six open strings of a standard-tuned guitar as one system, impose a hard cents budget, and select the integer network — asking on one side which coincidences an amplified instrument could plausibly use, and on the other how the same tunings look as a single subharmonic lattice. Modest, but it seems to be an unclaimed corner.

---

## Trying it

Any tuner that displays cents can set the table above: E strings at zero, A at −2, D at −4, G at −2.5, B at +2. (If you tune A, D and B with the old fifth- and seventh-fret harmonics method, you are already there; only G needs the tuner.)

What would count as evidence? Not "it sounds mystical." Something more like: with identical gain staging, does the guitar enter feedback faster, or favor different pitches, than the same guitar tuned to strict equal temperament? Do open chords ring measurably longer? A spectrogram of both takes would settle more than any amount of description.

Equal temperament asks where each note should be. This experiment asks a slightly different question — where the energy of one particular instrument, with six strings ringing at once, might prefer to meet. The mathematics above guarantees only that the meeting points exist. Whether the guitar cares is what the experiment is for.
