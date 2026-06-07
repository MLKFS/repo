# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This is the monorepo for **MLKFS LLC** — a California audio-visual, software, and
creative company. It hosts two distinct things:

1. The public marketing website served at [mlkfs.com](https://mlkfs.com) (Astro).
2. Open-source applications under `apps/<name>/`, each self-contained with its own
   toolchain and README.

Keep these separated: product/application code lives under `apps/<name>/`. The
website links out to those app folders rather than embedding product code in the
site source tree.

## Website (Astro)

The site is a static Astro 5 build styled with **Tailwind CSS v4** (via the
`@tailwindcss/vite` plugin, configured in `astro.config.mjs` — note Tailwind v4 is
configured in CSS, so `tailwind.config.cjs` is mostly vestigial). TypeScript runs
in Astro's `strict` mode.

### Commands

```bash
npm install        # install dependencies
npm run dev        # local dev server (astro dev)
npm run build      # production build to dist/
npm run preview    # preview the production build
```

There is no test suite or linter wired up for the website — `npm run build` (which
type-checks `.astro` files) is the de facto verification step before pushing.

### Architecture

- `src/layouts/BaseLayout.astro` — the single shared shell (html/head, `<Navbar>`,
  `<slot>`, `<Footer>`). Every page imports it and passes `title`/`description`.
- `src/pages/*.astro` — file-based routing. Nested routes live in subfolders
  (e.g. `src/pages/software/batt-sail.astro` → `/software/batt-sail`).
- `src/components/` — `Navbar`, `Footer`, `HeroReel`.
- `src/styles/global.css` — global styles plus reusable utility classes
  (`.container-xl`, `.btn-accent`, `.navbar` states). The brand accent is a single
  CSS variable `--accent` (macOS "Citrus" lime `#b5d65a`); change the tone there.
- `public/` — static assets served at the site root (logos, downloads, media,
  `hero-lab.html`).

Most interactive behavior is plain inline `<script>` in components (no framework
islands): the `Navbar` scroll/scrolled state, mobile menu, and logo strip hover are
all hand-written vanilla JS.

### HeroReel and the hidden "hero lab"

`src/components/HeroReel.astro` renders the word "MLKFS" as a live procedural
halftone animation drawn on a `<canvas>` (no video file). It degrades to plain text
under reduced-motion / no-JS. **Easter egg / dev gate:** 7 clicks on the hero canvas
within 1.5s navigates to `/hero-lab.html` (a standalone tuning playground in
`public/`). If you touch the hero animation, the tap-gate lives at the bottom of
HeroReel's `<script>`.

### Contact form

`src/pages/contact.astro` posts to **Formspree** (`formspree.io/f/xanbpgvb`) with a
`_gotcha` honeypot field. Successful submissions redirect to `/thanks`.

## Deployment

Pushing to `main` (or `master`) triggers `.github/workflows/deploy.yml`, which runs
`npm ci && npm run build` and publishes `dist/` to **GitHub Pages**. The custom
domain is pinned by the root `CNAME` file (`mlkfs.com`). There is no separate
staging environment — `main` is production.

A pre-apps-migration snapshot of the live site is preserved on the branch
`backup/site-before-apps-migration-2026-05-26` as a rollback point.

## apps/batt-sail (Swift macOS CLI)

A self-contained Swift Package Manager executable — a macOS battery charge-limit
CLI that talks to the SMC directly (`BCLM` on Intel/T2, `CHWA` on Apple Silicon).
It has **no relationship to the website's Node toolchain**; build it from within
`apps/batt-sail/`.

```bash
cd apps/batt-sail
swift build -c release           # build (Swift 5.7+, macOS 12+)
make universal                   # arm64+x86_64 lipo'd binary → dist/batt-sail
sudo make install                # install to /usr/local/bin
```

Key source: `Sources/BattSail/main.swift` (ArgumentParser CLI) and `SMC.swift`
(native SMC client adapted from MIT-licensed zackelia/bclm + SMCKit — see
`THIRD_PARTY_NOTICES.md`). The core idea is **hysteresis "sailing"** between a
`minPercent`/`maxPercent` band to avoid micro-charging; config persists at
`/Library/Application Support/batt-sail/config.json`. There is no automated test
suite — `apps/batt-sail/README.md` documents a manual "Test checklist" to run on
target Intel hardware (most commands require `sudo`; only `status`/`backend`/
`doctor` are read-only). The prebuilt universal binary is committed at
`public/downloads/batt-sail-darwin-universal` and distributed via the website and a
Homebrew formula (`apps/batt-sail/Formula/batt-sail.rb`).

When adding a new app, follow this pattern: a top-level `apps/<name>/` folder owning
its own build, README, and license notices, with the website linking to it.
