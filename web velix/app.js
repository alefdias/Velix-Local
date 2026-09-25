/**
 * VELIX LOCAL — OFFICIAL WEB PORTAL
 * Logic: OS Detection, GitHub API Releases, 1-Click Instant Downloads, Theme Toggle
 */

const GITHUB_REPO = 'alefdias/Velix-Local';
const DEFAULT_VERSION = 'v1.0.7';

// Fallback direct release download URLs (GitHub redirects /latest/download/<file> directly)
const FALLBACK_DOWNLOADS = {
  android: `https://github.com/${GITHUB_REPO}/releases/latest/download/velix-local-android.apk`,
  windows: `https://github.com/${GITHUB_REPO}/releases/latest/download/velix-local-windows-x64.zip`,
  fedora:  `https://github.com/${GITHUB_REPO}/releases/latest/download/velix-local-fedora-x86_64.rpm`,
  ubuntu:  `https://github.com/${GITHUB_REPO}/releases/latest/download/velix-local-ubuntu-amd64.deb`,
  linux:   `https://github.com/${GITHUB_REPO}/releases/latest/download/velix-local-linux-x64.tar.gz`,
};

// State
let currentRelease = {
  version: DEFAULT_VERSION,
  assets: {},
};

document.addEventListener('DOMContentLoaded', () => {
  initTheme();
  detectOSAndHighlight();
  fetchLatestRelease();
});

/**
 * 1. Buscar a última release no GitHub API
 */
async function fetchLatestRelease() {
  try {
    const response = await fetch(`https://api.github.com/repos/${GITHUB_REPO}/releases/latest`);
    if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
    const data = await response.json();

    currentRelease.version = data.tag_name || DEFAULT_VERSION;

    // Mapear cada artefato para seu link direto de download em 1 clique
    if (data.assets && Array.isArray(data.assets)) {
      data.assets.forEach(asset => {
        const name = asset.name.toLowerCase();
        const url = asset.browser_download_url;
        const sizeMb = (asset.size / (1024 * 1024)).toFixed(1) + ' MB';

        if (name.endsWith('.apk')) {
          currentRelease.assets.android = { url, size: sizeMb };
        } else if (name.endsWith('.zip') && name.includes('windows')) {
          currentRelease.assets.windows = { url, size: sizeMb };
        } else if (name.endsWith('.rpm')) {
          currentRelease.assets.fedora = { url, size: sizeMb };
        } else if (name.endsWith('.deb')) {
          currentRelease.assets.ubuntu = { url, size: sizeMb };
        } else if (name.endsWith('.tar.gz')) {
          currentRelease.assets.linux = { url, size: sizeMb };
        }
      });
    }

    updateUIWithReleaseData();
  } catch (error) {
    console.warn('Usando links canônicos do GitHub:', error);
    updateUIWithFallback();
  }
}

/**
 * Atualiza a interface com os links e tamanhos recebidos da API
 */
function updateUIWithReleaseData() {
  // Atualizar badges de versão
  document.querySelectorAll('.release-version-tag').forEach(el => {
    el.textContent = currentRelease.version;
  });

  // Atualizar botões de download
  setButtonLink('btn-download-android', currentRelease.assets.android?.url || FALLBACK_DOWNLOADS.android);
  setButtonLink('btn-download-windows', currentRelease.assets.windows?.url || FALLBACK_DOWNLOADS.windows);
  setButtonLink('btn-download-fedora',  currentRelease.assets.fedora?.url  || FALLBACK_DOWNLOADS.fedora);
  setButtonLink('btn-download-ubuntu',  currentRelease.assets.ubuntu?.url  || FALLBACK_DOWNLOADS.ubuntu);
  setButtonLink('btn-download-linux',   currentRelease.assets.linux?.url   || FALLBACK_DOWNLOADS.linux);

  // Atualizar tamanhos se disponíveis
  if (currentRelease.assets.android?.size) setText('size-android', currentRelease.assets.android.size);
  if (currentRelease.assets.windows?.size) setText('size-windows', currentRelease.assets.windows.size);
  if (currentRelease.assets.fedora?.size)  setText('size-fedora',  currentRelease.assets.fedora.size);
  if (currentRelease.assets.ubuntu?.size)  setText('size-ubuntu',  currentRelease.assets.ubuntu.size);
  if (currentRelease.assets.linux?.size)   setText('size-linux',   currentRelease.assets.linux.size);

  // Atualizar botão principal do Hero
  updateHeroButton();
}

function updateUIWithFallback() {
  document.querySelectorAll('.release-version-tag').forEach(el => {
    el.textContent = DEFAULT_VERSION;
  });
  setButtonLink('btn-download-android', FALLBACK_DOWNLOADS.android);
  setButtonLink('btn-download-windows', FALLBACK_DOWNLOADS.windows);
  setButtonLink('btn-download-fedora',  FALLBACK_DOWNLOADS.fedora);
  setButtonLink('btn-download-ubuntu',  FALLBACK_DOWNLOADS.ubuntu);
  setButtonLink('btn-download-linux',   FALLBACK_DOWNLOADS.linux);
  updateHeroButton();
}

function setButtonLink(id, url) {
  const el = document.getElementById(id);
  if (el) {
    el.href = url;
    el.setAttribute('download', '');
  }
}

function setText(id, text) {
  const el = document.getElementById(id);
  if (el) el.textContent = text;
}

/**
 * 2. Detecção inteligente de Sistema Operacional do visitante
 */
let detectedPlatform = 'windows';

function detectOSAndHighlight() {
  const ua = navigator.userAgent.toLowerCase();
  const platform = navigator.platform.toLowerCase();

  let osName = 'Windows';
  let targetKey = 'windows';

  if (ua.includes('android')) {
    osName = 'Android';
    targetKey = 'android';
  } else if (ua.includes('fedora') || ua.includes('red hat') || ua.includes('rhel')) {
    osName = 'Fedora Linux';
    targetKey = 'fedora';
  } else if (ua.includes('ubuntu') || ua.includes('debian')) {
    osName = 'Ubuntu / Debian';
    targetKey = 'ubuntu';
  } else if (platform.includes('linux') || ua.includes('linux')) {
    osName = 'Linux';
    targetKey = 'fedora'; // Padrão Linux preferencial ou universal
  } else if (platform.includes('win') || ua.includes('windows')) {
    osName = 'Windows';
    targetKey = 'windows';
  } else if (platform.includes('mac') || ua.includes('macintosh')) {
    osName = 'macOS';
    targetKey = 'windows'; // Fallback
  }

  detectedPlatform = targetKey;

  // Atualizar label informativa
  const osLabel = document.getElementById('detected-os-text');
  if (osLabel) {
    osLabel.textContent = `Detectamos que você está usando ${osName}`;
  }

  // Destacar o card correspondente na grade
  document.querySelectorAll('.download-card').forEach(card => {
    card.classList.remove('highlight');
  });
  const activeCard = document.getElementById(`card-${targetKey}`);
  if (activeCard) {
    activeCard.classList.add('highlight');
  }

  updateHeroButton();
}

function updateHeroButton() {
  const heroBtn = document.getElementById('hero-download-btn');
  const heroBtnText = document.getElementById('hero-btn-text');
  if (!heroBtn) return;

  const url = currentRelease.assets[detectedPlatform]?.url || FALLBACK_DOWNLOADS[detectedPlatform];
  heroBtn.href = url;
  heroBtn.setAttribute('download', '');

  let title = 'Baixar para Windows';
  if (detectedPlatform === 'android') title = 'Baixar APK para Android';
  else if (detectedPlatform === 'fedora') title = 'Baixar Pacote Fedora (.rpm)';
  else if (detectedPlatform === 'ubuntu') title = 'Baixar Pacote Ubuntu (.deb)';
  else if (detectedPlatform === 'linux') title = 'Baixar para Linux (.tar.gz)';

  if (heroBtnText) {
    heroBtnText.textContent = `${title} (${currentRelease.version})`;
  }
}

/**
 * 3. Alternância de Tema Claro / Escuro
 */
function initTheme() {
  const toggleBtn = document.getElementById('theme-toggle');
  const savedTheme = localStorage.getItem('velix_theme') || 'light';
  document.documentElement.setAttribute('data-theme', savedTheme);
  updateThemeIcon(savedTheme);

  if (toggleBtn) {
    toggleBtn.addEventListener('click', () => {
      const current = document.documentElement.getAttribute('data-theme');
      const nextTheme = current === 'dark' ? 'light' : 'dark';
      document.documentElement.setAttribute('data-theme', nextTheme);
      localStorage.setItem('velix_theme', nextTheme);
      updateThemeIcon(nextTheme);
    });
  }
}

function updateThemeIcon(theme) {
  const icon = document.getElementById('theme-icon');
  if (!icon) return;
  if (theme === 'dark') {
    icon.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="5"></circle><line x1="12" y1="1" x2="12" y2="3"></line><line x1="12" y1="21" x2="12" y2="23"></line><line x1="4.22" y1="4.22" x2="5.64" y2="5.64"></line><line x1="18.36" y1="18.36" x2="19.78" y2="19.78"></line><line x1="1" y1="12" x2="3" y2="12"></line><line x1="21" y1="12" x2="23" y2="12"></line><line x1="4.22" y1="19.78" x2="5.64" y2="18.36"></line><line x1="18.36" y1="5.64" x2="19.78" y2="4.22"></line></svg>`;
  } else {
    icon.innerHTML = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>`;
  }
}
