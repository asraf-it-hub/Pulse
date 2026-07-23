import { mkdir, readFile, writeFile, cp, access } from "node:fs/promises";
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

// Copy optional distribution files if they exist
const optionalFiles = [
  "assets/pulse-android.apk",
  "assets/pulse-windows.zip",
];

for (const file of optionalFiles) {
  const from = resolve(source, file);
  const to = resolve(output, file);
  try {
    await access(from);
    await mkdir(dirname(to), { recursive: true });
    await writeFile(to, await readFile(from));
    console.log(`Copied optional asset to dist: ${file}`);
  } catch {
    console.log(`Optional asset not found: ${file}. Skipping.`);
  }
}

// Copy Web application folder if it exists
const webAppSource = resolve(root, "app", "build", "web");
const webAppDest = resolve(output, "app");
try {
  await cp(webAppSource, webAppDest, { recursive: true });
  console.log("Web application build copied to dist/app");
} catch {
  console.log("Web application build not found. Skipping web app copy.");
}

console.log(`Website build ready: ${output}`);
