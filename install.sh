#!/usr/bin/env bash
# ============================================================================
#  PHOSPHOR  —  Hyprland green-on-black theme installer
#  One-command setup for the whole look: Hyprland, Waybar, Kitty, Rofi, Dunst,
#  GTK (3/4), Qt (5/6 + Kvantum), KDE color scheme, cursors, icons, wallpaper.
# ============================================================================
set -euo pipefail

# --- pretty output -----------------------------------------------------------
GREEN='\033[0;32m'; BOLD='\033[1m'; DIM='\033[2m'; RED='\033[0;31m'; NC='\033[0m'
say()  { echo -e "${GREEN}${BOLD}::${NC} $*"; }
info() { echo -e "   ${DIM}$*${NC}"; }
warn() { echo -e "${RED}!!${NC} $*"; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="$HOME/.config"
BACKUP="$HOME/.phosphor-backup/$(date +%Y%m%d-%H%M%S)"

# --- sanity ------------------------------------------------------------------
if ! command -v pacman >/dev/null 2>&1; then
  warn "This theme targets Arch/Hyprland (pacman). Aborting."; exit 1
fi

# --- 1. packages -------------------------------------------------------------
PKGS_REPO=(
  hyprland hyprlock hypridle xdg-desktop-portal-hyprland
  waybar dunst rofi kitty
  qt5ct qt6ct kvantum
  papirus-icon-theme bibata-cursor-theme
  ttf-jetbrains-mono-nerd ttf-nerd-fonts-symbols
  wl-clipboard cliphist polkit-gnome network-manager-applet blueman
  python
)
PKGS_AUR=( neowall-git )   # GPU shader wallpaper daemon

install_pkgs() {
  say "Installing packages"
  local helper=""
  for h in paru yay; do command -v "$h" >/dev/null 2>&1 && helper="$h" && break; done

  info "Syncing official repo packages (sudo)…"
  sudo pacman -S --needed --noconfirm "${PKGS_REPO[@]}" || warn "some repo pkgs failed (continuing)"

  if [ -n "$helper" ]; then
    info "Installing AUR packages via $helper…"
    "$helper" -S --needed --noconfirm "${PKGS_AUR[@]}" || warn "AUR install failed (neowall optional)"
  else
    warn "No AUR helper (paru/yay) found — skipping: ${PKGS_AUR[*]}"
    warn "Install neowall manually for the animated wallpaper, or the theme works without it."
  fi
}

# --- 2. backup + link/copy configs -------------------------------------------
backup() {   # $1 = target path to preserve if it exists
  [ -e "$1" ] || return 0
  mkdir -p "$BACKUP/$(dirname "${1#$HOME/}")"
  cp -a "$1" "$BACKUP/${1#$HOME/}"
}

deploy_config() {
  say "Deploying theme configs (backups → $BACKUP)"
  mkdir -p "$CFG"
  # copy each top-level dir under config/ into ~/.config, backing up first
  for src in "$REPO_DIR"/config/*/; do
    name="$(basename "$src")"
    dest="$CFG/$name"
    backup "$dest"
    mkdir -p "$dest"
    cp -a "$src." "$dest/"
    info "~/.config/$name"
  done

  # substitute __HOME__ placeholder in qt configs
  sed -i "s|__HOME__|$HOME|g" "$CFG/qt5ct/qt5ct.conf" "$CFG/qt6ct/qt6ct.conf" 2>/dev/null || true
}

deploy_home() {
  say "Deploying home-level files (kdeglobals)"
  backup "$HOME/.config/kdeglobals"
  cp -a "$REPO_DIR/home/kdeglobals" "$CFG/kdeglobals"
  info "~/.config/kdeglobals"
}

deploy_kde_scheme() {
  say "Installing KDE Phosphor color scheme"
  mkdir -p "$HOME/.local/share/color-schemes"
  cp -a "$REPO_DIR/kde/color-schemes/Phosphor.colors" "$HOME/.local/share/color-schemes/"
  info "~/.local/share/color-schemes/Phosphor.colors"
}

# --- 3. icons: green Papirus folders -----------------------------------------
apply_icons() {
  say "Setting Papirus folders to green"
  if command -v papirus-folders >/dev/null 2>&1; then
    papirus-folders -C green --theme Papirus-Dark >/dev/null 2>&1 || warn "papirus-folders failed"
  else
    info "papirus-folders not installed — skipping (install it for green folders)"
  fi
  command -v gtk-update-icon-cache >/dev/null 2>&1 && \
    sudo gtk-update-icon-cache -f /usr/share/icons/Papirus-Dark >/dev/null 2>&1 || true
}

# --- 4. gsettings (GTK apps read these under Wayland) -------------------------
apply_gsettings() {
  command -v gsettings >/dev/null 2>&1 || return 0
  say "Applying gsettings (GTK theme/icon/cursor)"
  local S=org.gnome.desktop.interface
  gsettings set $S gtk-theme       'catppuccin-mocha-green-standard+default' 2>/dev/null || true
  gsettings set $S icon-theme      'Papirus-Dark' 2>/dev/null || true
  gsettings set $S cursor-theme    'Bibata-Modern-Amber' 2>/dev/null || true
  gsettings set $S color-scheme    'prefer-dark' 2>/dev/null || true
  gsettings set $S font-name       'JetBrainsMono Nerd Font 10' 2>/dev/null || true
}

# --- 5. Kvantum theme --------------------------------------------------------
apply_kvantum() {
  command -v kvantummanager >/dev/null 2>&1 || return 0
  say "Setting Kvantum theme (optional Sweet)"
  info "Kvantum config deployed; Qt uses Fusion+Phosphor by default."
}

# --- run ---------------------------------------------------------------------
main() {
  echo -e "${GREEN}${BOLD}"
  echo "  ┌─────────────────────────────────────────────┐"
  echo "  │   PHOSPHOR  ·  green-on-black Hyprland theme  │"
  echo "  └─────────────────────────────────────────────┘"
  echo -e "${NC}"

  local SKIP_PKGS="${PHOSPHOR_SKIP_PKGS:-0}"
  if [ "$SKIP_PKGS" != "1" ]; then install_pkgs; else say "Skipping package install (PHOSPHOR_SKIP_PKGS=1)"; fi

  deploy_config
  deploy_home
  deploy_kde_scheme
  apply_icons
  apply_gsettings
  apply_kvantum

  echo
  say "Done! 🟢"
  echo -e "   Backups of anything overwritten are in: ${BOLD}$BACKUP${NC}"
  echo -e "   Reload Hyprland:  ${BOLD}hyprctl reload${NC}"
  echo -e "   For Qt/KDE changes, ${BOLD}log out and back in${NC}."
  echo
  warn "NVIDIA note: hyprland.conf sets NVIDIA env vars. On AMD/Intel, comment out"
  warn "the LIBVA_DRIVER_NAME / __GLX_VENDOR_LIBRARY_NAME / NVD_BACKEND lines."
}

main "$@"
