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

// Interactive Player Mockup
const playerShell = document.querySelector(".player-shell");
const playBtn = document.querySelector(".controls .play");
const progressBar = document.querySelector(".progress span");
const trackTitle = document.querySelector(".meta-text strong");

const tracks = [
  "Midnight Signal",
  "Pulse Wave Ride",
  "Vapor Trail",
  "Aura Frequency"
];
let currentTrackIndex = 0;
let progressPercent = 0;
let playInterval = null;

function updateProgress() {
  progressPercent += 0.5;
  if (progressPercent > 100) {
    progressPercent = 0;
    currentTrackIndex = (currentTrackIndex + 1) % tracks.length;
    if (trackTitle) {
      trackTitle.textContent = tracks[currentTrackIndex];
    }
  }
  if (progressBar) {
    progressBar.style.width = `${progressPercent}%`;
  }
}

playBtn?.addEventListener("click", () => {
  if (playerShell?.classList.contains("playing")) {
    playerShell.classList.remove("playing");
    clearInterval(playInterval);
  } else {
    playerShell?.classList.add("playing");
    playInterval = setInterval(updateProgress, 50);
  }
});

// Oddly Satisfying Magnetic Card Tilt Effect
const cards = document.querySelectorAll(".feature-card");
cards.forEach((card) => {
  card.addEventListener("mousemove", (e) => {
    const rect = card.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;
    
    const centerX = rect.width / 2;
    const centerY = rect.height / 2;
    
    const rotateX = ((centerY - y) / centerY) * 10; // max 10 degrees
    const rotateY = ((x - centerX) / centerX) * 10;
    
    card.style.transform = `perspective(1000px) rotateX(${rotateX}deg) rotateY(${rotateY}deg) scale(1.03)`;
    card.style.boxShadow = "0 20px 40px rgba(0,0,0,0.25)";
  });
  
  card.addEventListener("mouseleave", () => {
    card.style.transform = "perspective(1000px) rotateX(0deg) rotateY(0deg) scale(1)";
    card.style.boxShadow = "";
  });
});
