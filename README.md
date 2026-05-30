# MLKFS — Audio-Visual, Software & Creative 🎬🎧💻

**MLKFS LLC** is a California-based company working across audio-visual, software, and creative fields.  
We build and apply technology — in image, sound, and software — for projects worldwide.  

Our scope covers:  
🎞️ Video Editing · 🎨 Color Grading · 🔊 Sound Design  
🎚️ Music Mixing & Mastering · 📺 YouTube Channel Management  
🎼 LUT Packs & Themed Music · 🌍 Timelapse Stock Video  

Our work blends technical precision with creative vision: cutting, grading, mixing, and mastering so that stories resonate across formats and platforms. Whether a short film, a YouTube channel, or a musical release, we believe editing, color, and sound are universal languages.  

🌐 [mlkfs.com](https://mlkfs.com) • MLKFS LLC • All rights reserved

## Repository layout

This repository hosts the public MLKFS website and open-source applications.

- `src/` - Astro website served at [mlkfs.com](https://mlkfs.com)
- `apps/batt-sail/` - macOS battery sailing CLI
- `.github/workflows/deploy.yml` - GitHub Pages deployment workflow

Application code should live under `apps/<name>/`. The website should link to
those app folders instead of mixing product code into the site source tree.

## Rollback point

Before adding application code, the live website state was preserved on:

```bash
backup/site-before-apps-migration-2026-05-26
```

If a deployment ever needs to be rolled back, restore `main` to that branch from
GitHub or with a protected fast recovery flow.
