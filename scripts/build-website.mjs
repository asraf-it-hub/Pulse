import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const source = resolve(root, "website");
const output = resolve(root, "dist", "pulse-website");
const files = [
  "index.html",
  "styles.css",
  "script.js",
  "privacy.html",
  "terms.html",
  "assets/pulse-logo.png",
];

for (const file of files) {
  const from = resolve(source, file);
  const to = resolve(output, file);
  await mkdir(dirname(to), { recursive: true });
  await writeFile(to, await readFile(from));
}

console.log(`Website build ready: ${output}`);
