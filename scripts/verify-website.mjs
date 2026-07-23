import { access, readFile, stat } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "..");
const website = resolve(root, "website");
const requiredFiles = [
  "index.html",
  "styles.css",
  "script.js",
  "privacy.html",
  "terms.html",
  "assets/pulse-logo.png",
];

const checks = [];
const pass = (name) => checks.push({ name, ok: true });
const fail = (name, message) => checks.push({ name, ok: false, message });

for (const file of requiredFiles) {
  try {
    await access(resolve(website, file));
    pass(`exists: ${file}`);
  } catch {
    fail(`exists: ${file}`, "Missing required website file.");
  }
}

const index = await readFile(resolve(website, "index.html"), "utf8");
const css = await readFile(resolve(website, "styles.css"), "utf8");
const script = await readFile(resolve(website, "script.js"), "utf8");
const logoStats = await stat(resolve(website, "assets/pulse-logo.png"));

const requiredText = [
  "PULSE",
  "Android",
  "Windows",
  "Web",
  "Privacy Policy",
  "Terms",
  "FAQ",
  "Download",
];
for (const text of requiredText) {
  index.includes(text) ? pass(`content: ${text}`) : fail(`content: ${text}`, "Expected landing page copy is missing.");
}

const requiredAnchors = ["#features", "#signature", "#downloads", "#faq", "privacy.html", "terms.html"];
for (const anchor of requiredAnchors) {
  index.includes(`href="${anchor}"`) ? pass(`link: ${anchor}`) : fail(`link: ${anchor}`, "Expected link target is missing.");
}

const featureCards = (index.match(/class="feature-card"/g) ?? []).length;
featureCards >= 4 ? pass("feature card count") : fail("feature card count", `Expected at least 4 feature cards, found ${featureCards}.`);

const downloadCards = (index.match(/class="dl-card/g) ?? []).length;
downloadCards === 3 ? pass("download card count") : fail("download card count", `Expected 3 download cards, found ${downloadCards}.`);

logoStats.size > 1000 ? pass("logo asset non-empty") : fail("logo asset non-empty", "Logo asset is unexpectedly small.");

const failed = checks.filter((check) => !check.ok);
for (const check of checks) {
  console.log(`${check.ok ? "PASS" : "FAIL"} ${check.name}${check.message ? ` - ${check.message}` : ""}`);
}

if (failed.length > 0) {
  process.exitCode = 1;
}
