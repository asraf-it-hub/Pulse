// Pulse Official Provider Website - Interactive Canvas & OS Detection
document.addEventListener('DOMContentLoaded', () => {
  // 1. Detect User OS & Highlight Card
  detectOS();

  // 2. Interactive Canvas Organic Visualizer Engine
  initCanvasVisualizer();

  // 3. Interactive Boost Slider
  initBoostSlider();
});

function detectOS() {
  const ua = navigator.userAgent.toLowerCase();
  const androidCard = document.getElementById('dlAndroid');
  const windowsCard = document.getElementById('dlWindows');

  if (/android/i.test(ua)) {
    if (androidCard) androidCard.style.borderColor = 'var(--primary)';
  } else if (/win/i.test(ua)) {
    if (windowsCard) windowsCard.style.borderColor = 'var(--primary)';
  }
}

let isPlaying = false;
let boostVolume = 100;
let animFrameId = null;

function initCanvasVisualizer() {
  const canvas = document.getElementById('heroVisualizerCanvas');
  if (!canvas) return;

  const ctx = canvas.getContext('2d');
  const dpr = window.devicePixelRatio || 1;
  canvas.width = 320 * dpr;
  canvas.height = 320 * dpr;

  const demoPlayBtn = document.getElementById('demoPlayBtn');
  const playIcon = document.getElementById('playIcon');
  const pauseIcon = document.getElementById('pauseIcon');
  const statusBadge = document.getElementById('demoStatusBadge');

  if (demoPlayBtn) {
    demoPlayBtn.addEventListener('click', () => {
      isPlaying = !isPlaying;
      if (isPlaying) {
        playIcon.classList.add('hidden');
        pauseIcon.classList.remove('hidden');
        statusBadge.textContent = 'PLAYING';
        statusBadge.style.background = 'rgba(85, 214, 190, 0.2)';
        statusBadge.style.color = 'var(--accent-teal)';
        statusBadge.style.borderColor = 'var(--accent-teal)';
      } else {
        pauseIcon.classList.add('hidden');
        playIcon.classList.remove('hidden');
        statusBadge.textContent = 'READY';
        statusBadge.style.background = 'rgba(255, 107, 61, 0.2)';
        statusBadge.style.color = 'var(--primary)';
        statusBadge.style.borderColor = 'var(--primary)';
      }
    });
  }

  // 32 Orbiting Particles
  const particles = Array.from({ length: 32 }, () => ({
    radiusOffset: Math.random() * 30,
    speed: (Math.random() * 0.8 + 0.4) * (Math.random() > 0.5 ? 1 : -1),
    angle: Math.random() * Math.PI * 2,
    size: Math.random() * 2.5 + 1.2,
    alpha: Math.random() * 0.6 + 0.4,
  }));

  let time = 0;

  function render() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    const baseRadius = canvas.width * 0.28;

    if (isPlaying) {
      time += 0.03 * (boostVolume / 100);
    } else {
      time += 0.005;
    }

    const bassPulse = isPlaying ? Math.pow(Math.abs(Math.sin(time * 3.2)), 2.2) * (boostVolume / 100) : 0.05;
    const midDeform = isPlaying ? Math.sin(time * 5.8) : 0.02;

    // Outer Glow Halo
    const glowRadius = baseRadius + 24 + bassPulse * 24;
    const gradient = ctx.createRadialGradient(centerX, centerY, baseRadius * 0.8, centerX, centerY, glowRadius);
    const isBoosted = boostVolume > 100;

    const primaryColor = isBoosted ? '#ff4500' : '#ff6b3d';
    gradient.addColorStop(0, primaryColor + '66');
    gradient.addColorStop(1, 'transparent');

    ctx.fillStyle = gradient;
    ctx.beginPath();
    ctx.arc(centerX, centerY, glowRadius, 0, Math.PI * 2);
    ctx.fill();

    // 4 Organic Morphing Wave Rings
    for (let ring = 0; ring < 4; ring++) {
      const ringRadius = baseRadius + ring * 14 + bassPulse * 12;
      ctx.beginPath();
      const numPoints = 140;

      for (let i = 0; i <= numPoints; i++) {
        const theta = (i / numPoints) * Math.PI * 2;
        const distortion =
          Math.sin(theta * 7 + time * 1.2 + ring) * (8 + midDeform * 14) +
          Math.cos(theta * 4 - time * 0.9 + ring * 0.5) * (6 + bassPulse * 10);

        const r = ringRadius + distortion;
        const x = centerX + r * Math.cos(theta);
        const y = centerY + r * Math.sin(theta);

        if (i === 0) {
          ctx.moveTo(x, y);
        } else {
          ctx.lineTo(x, y);
        }
      }
      ctx.closePath();

      ctx.strokeStyle = primaryColor;
      ctx.globalAlpha = Math.max(0.1, 0.85 - ring * 0.18);
      ctx.lineWidth = (2.2 - ring * 0.4) * dpr;
      ctx.stroke();
    }
    ctx.globalAlpha = 1.0;

    // Orbiting Particles
    particles.forEach((p) => {
      if (isPlaying) {
        p.angle += p.speed * 0.018 * (boostVolume / 100);
      }
      const r = baseRadius + 30 + p.radiusOffset + bassPulse * 12;
      const px = centerX + r * Math.cos(p.angle);
      const py = centerY + r * Math.sin(p.angle);

      ctx.fillStyle = isBoosted ? '#ffaa00' : '#ff6b3d';
      ctx.globalAlpha = p.alpha;
      ctx.beginPath();
      ctx.arc(px, py, p.size * dpr, 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.globalAlpha = 1.0;

    requestAnimationFrame(render);
  }

  render();
}

function initBoostSlider() {
  const boostSlider = document.getElementById('boostSlider');
  const boostLabel = document.getElementById('boostLabel');

  if (boostSlider && boostLabel) {
    boostSlider.addEventListener('input', (e) => {
      boostVolume = parseInt(e.target.value, 10);
      if (boostVolume > 100) {
        boostLabel.textContent = `🔥 ${boostVolume}% SUPERCHARGED`;
        boostLabel.style.color = '#ff4500';
      } else {
        boostLabel.textContent = `${boostVolume}%`;
        boostLabel.style.color = 'var(--primary)';
      }
    });
  }
}
