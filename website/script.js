const root = document.documentElement;
const toggle = document.querySelector(".theme-toggle");
const savedTheme = localStorage.getItem("pulse-theme");

if (savedTheme) {
  root.dataset.theme = savedTheme;
}

toggle?.addEventListener("click", () => {
  const nextTheme = root.dataset.theme === "light" ? "dark" : "light";
  root.dataset.theme = nextTheme;
  localStorage.setItem("pulse-theme", nextTheme);
});
