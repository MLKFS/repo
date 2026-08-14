/**
 * Generates the static social-sharing cards in public/og/.
 *
 * Run with `npm run og` after adding or retitling an essay; the PNGs are
 * committed so the site build stays a plain static build with no extra deps.
 */
import { readdir, readFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import path from "node:path";
import sharp from "sharp";

const root = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const BLOG_DIR = path.join(root, "src/content/blog");
const OUT_DIR = path.join(root, "public/og");
const LOGO = path.join(root, "public/mlkfs-logo.png");

const WIDTH = 1200;
const HEIGHT = 630;
const PAD = 72;
const ACCENT = "#b5d65a";
const FONT = "Liberation Sans, DejaVu Sans, Helvetica, Arial, sans-serif";

/** Rough per-character advance widths (fraction of font size) for Liberation Sans. */
const NARROW = new Set([..."ijlt.,:;'!|()[]/ "]);
const WIDE = new Set([..."mwMW@"]);
const UPPER = /[A-ZÀ-ÞĞİÖÜÇŞ]/;

function textWidth(text, size, bold) {
  let units = 0;
  for (const ch of text) {
    if (ch === " ") units += 0.28;
    else if (NARROW.has(ch)) units += 0.31;
    else if (WIDE.has(ch)) units += 0.86;
    else if (UPPER.test(ch)) units += 0.69;
    else if (/[0-9]/.test(ch)) units += 0.56;
    else units += 0.54;
  }
  return units * size * (bold ? 1.045 : 1);
}

function wrap(text, size, maxWidth, bold) {
  const lines = [];
  let line = "";
  for (const word of text.split(/\s+/)) {
    const candidate = line ? `${line} ${word}` : word;
    if (line && textWidth(candidate, size, bold) > maxWidth) {
      lines.push(line);
      line = word;
    } else {
      line = candidate;
    }
  }
  if (line) lines.push(line);
  return lines;
}

/** Shrinks the font until the wrapped text fits within maxLines. */
function fit(text, { start, min, maxWidth, maxLines, bold }) {
  let size = start;
  let lines = wrap(text, size, maxWidth, bold);
  while (lines.length > maxLines && size > min) {
    size -= 2;
    lines = wrap(text, size, maxWidth, bold);
  }
  return { size, lines };
}

const esc = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");

function tspans(lines, x, y, lineHeight) {
  return lines
    .map((l, i) => `<tspan x="${x}" y="${y + i * lineHeight}">${esc(l)}</tspan>`)
    .join("");
}

function cardSvg({ title, subtitle, byline }) {
  const inner = WIDTH - PAD * 2;
  const t = fit(title, { start: 66, min: 44, maxWidth: inner, maxLines: 3, bold: true });
  const s = subtitle
    ? fit(subtitle, { start: 30, min: 24, maxWidth: inner - 40, maxLines: 3, bold: false })
    : null;

  const titleTop = 268;
  const titleLH = Math.round(t.size * 1.22);
  const subTop = titleTop + (t.lines.length - 1) * titleLH + 68;
  const subLH = s ? Math.round(s.size * 1.42) : 0;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="#ffffff"/>
  <rect width="${WIDTH}" height="10" fill="${ACCENT}"/>
  <g font-family="${FONT}">
    <text x="${PAD}" y="${titleTop}" font-size="${t.size}" font-weight="700" fill="#000000" letter-spacing="-0.5">${tspans(t.lines, PAD, titleTop, titleLH)}</text>
    ${s ? `<text x="${PAD}" y="${subTop}" font-size="${s.size}" font-weight="400" fill="#4b5563">${tspans(s.lines, PAD, subTop, subLH)}</text>` : ""}
    <rect x="${PAD}" y="${HEIGHT - 148}" width="56" height="3" fill="${ACCENT}"/>
    <text x="${PAD}" y="${HEIGHT - 96}" font-size="26" font-weight="600" fill="#000000">${esc(byline)}</text>
    <text x="${PAD}" y="${HEIGHT - 56}" font-size="22" font-weight="400" fill="#6b7280">mlkfs.com/blog</text>
  </g>
</svg>`;
}

function defaultCardSvg() {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${WIDTH}" height="${HEIGHT}" viewBox="0 0 ${WIDTH} ${HEIGHT}">
  <rect width="${WIDTH}" height="${HEIGHT}" fill="#ffffff"/>
  <rect width="${WIDTH}" height="10" fill="${ACCENT}"/>
  <g font-family="${FONT}">
    <text x="${PAD}" y="${HEIGHT / 2 + 66}" font-size="34" font-weight="400" fill="#4b5563">Audio-Visual, Software &amp; Creative</text>
    <text x="${PAD}" y="${HEIGHT - 64}" font-size="22" font-weight="400" fill="#6b7280">mlkfs.com</text>
  </g>
</svg>`;
}

/** Minimal frontmatter reader — the fields this project's blog schema defines. */
function frontmatter(raw) {
  const match = raw.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};
  const data = {};
  for (const line of match[1].split(/\r?\n/)) {
    const kv = line.match(/^(\w+):\s*(.*)$/);
    if (!kv) continue;
    data[kv[1]] = kv[2].trim().replace(/^["'](.*)["']$/, "$1");
  }
  return data;
}

async function render(svg, outPath, logo) {
  const base = sharp(Buffer.from(svg));
  const composited = logo
    ? base.composite([{ input: logo.buffer, top: logo.top, left: PAD }])
    : base;
  await composited.png().toFile(outPath);
  console.log("wrote", path.relative(root, outPath));
}

const logoBuffer = await sharp(LOGO).resize({ width: 168 }).png().toBuffer();
const bigLogoBuffer = await sharp(LOGO).resize({ width: 300 }).png().toBuffer();
const bigLogoHeight = (await sharp(bigLogoBuffer).metadata()).height;

await mkdir(path.join(OUT_DIR, "blog"), { recursive: true });

await render(defaultCardSvg(), path.join(OUT_DIR, "mlkfs.png"), {
  buffer: bigLogoBuffer,
  top: Math.round(HEIGHT / 2 - bigLogoHeight - 34),
});

for (const file of (await readdir(BLOG_DIR)).filter((f) => f.endsWith(".md"))) {
  const data = frontmatter(await readFile(path.join(BLOG_DIR, file), "utf8"));
  const date = new Date(data.pubDate).toLocaleDateString("en-US", {
    year: "numeric",
    month: "long",
    day: "numeric",
    timeZone: "UTC",
  });
  const svg = cardSvg({
    title: data.title,
    subtitle: data.subtitle,
    byline: `${data.author} · ${data.organization ?? "MLKFS"} · ${date}`,
  });
  await render(svg, path.join(OUT_DIR, "blog", file.replace(/\.md$/, ".png")), {
    buffer: logoBuffer,
    top: PAD + 12,
  });
}
