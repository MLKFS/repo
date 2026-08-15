---
title: "Let the Battery Sail"
subtitle: "A small tool for making production hardware last a little longer."
description: "Why Batt-Sail uses a wider battery charge range to rethink laptop longevity for independent creators and production machines."
pubDate: 2026-08-16
author: "Ege Batuhan Akgül"
organization: "MLKFS"
---

Most professional laptops are portable in theory.

In practice, many of them live on a desk, connected to power for weeks at a time. The battery is there for the flight, the location shoot, the client meeting, the power cut — not for the ordinary Tuesday afternoon. We buy machines designed to move, and then we mostly ask them to sit still.

That leaves the cell in an unusual position. It spends most of its life full.

Holding a lithium-ion battery at 100% for long periods is generally considered less than ideal for its long-term health, and recent systems have started to account for this. macOS and others now offer charge management that keeps the battery near 80% when a machine is mostly stationary. That is a genuine improvement over charging everything to full and leaving it there.

But a ceiling describes only one number: the top.

It says less about what happens afterwards — when the machine reaches that number and then stays plugged in for another eleven days. A battery that is being held near a single target does not simply stop. It drifts down slightly, gets topped back up, drifts again. Whether those small corrections matter, and how much, is not something we are in a position to state as settled fact.

What we can do is design around a different assumption.

Batt-Sail takes the view that a battery might be better left alone than continuously managed toward one exact figure. Instead of a single ceiling, it defines a band — by default, between 70% and 80%. When the charge reaches the top of that band, charging stops. It does not resume until the battery has drifted down to the bottom of it. In between, Batt-Sail does nothing at all. No corrections, no adjustments. The battery is allowed to sail.

This is a philosophy, not a proof. It is an argument for fewer, wider movements rather than constant small ones.

We built it for our own machines — Intel MacBook Pros that spend most of their working life on AC power — and used it long before considering that anyone else might want it. It is a [small macOS command-line tool](/software/batt-sail), and it is now open to whoever finds it useful.

The reason to care about any of this is not really the battery.

A battery that lasts longer means a machine that lasts longer, one less replacement, one less device retired early for a reason that has nothing to do with its actual capability. Hardware that stays useful is the quietest form of environmental sense there is.

And it matters unevenly. For an organization, a battery replacement is a line item and a scheduled afternoon. For an independent filmmaker, musician, developer or photographer, the laptop is the edit suite, the studio, the archive and the office at once — usually bought with their own savings, often after waiting for them.

Longevity, in that light, is not only an engineering problem.

It is a question of who gets to keep working.
