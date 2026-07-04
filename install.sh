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
  hyprland hyprlock hypridle
  xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xdg-desktop-portal
  waybar dunst rofi kitty alacritty
  qt5ct qt6ct kvantum qt5-wayland qt6-wayland
  papirus-icon-theme bibata-cursor-theme
  ttf-jetbrains-mono-nerd ttf-firacode-nerd ttf-nerd-fonts-symbols
  wl-clipboard cliphist grim slurp polkit-gnome network-manager-applet blueman libnotify
  satty wf-recorder jq fzf hyprpicker wlogout brightnessctl playerctl
  pipewire wireplumber dolphin gvfs libcanberra
  glib2 python
  python-gobject gtk4 libadwaita   # native GTK4 appearance GUI (wear-gui)
  adw-gtk-theme                    # neutral GTK3 base recoloured by the palette
)
PKGS_AUR=(
  neowall-git                 # GPU shader wallpaper daemon
  catppuccin-gtk-theme-mocha  # base GTK theme the phosphor css overrides
  catppuccin-gtk-theme-latte  # light-mode GTK base (Catppuccin Latte theme)
  papirus-folders             # recolors Papirus folders green
)

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
  # copy each top-level dir under config/ into ~/.config, backing up first.
  # Template (*.tmpl) files stay in the repo — the `theme` switcher renders them.
  for src in "$REPO_DIR"/config/*/; do
    name="$(basename "$src")"
    dest="$CFG/$name"
    backup "$dest"
    mkdir -p "$dest"
    cp -a "$src." "$dest/"
    find "$dest" -name '*.tmpl' -delete 2>/dev/null || true
    info "~/.config/$name"
  done

  # substitute __HOME__ placeholder in templated configs
  sed -i "s|__HOME__|$HOME|g" \
    "$CFG/qt5ct/qt5ct.conf" "$CFG/qt6ct/qt6ct.conf" 2>/dev/null || true

  # make hypr helper scripts (screenshot/record) executable
  chmod +x "$CFG"/hypr/scripts/*.sh 2>/dev/null || true
}

deploy_local_bin() {
  say "Installing helper scripts to ~/.local/bin"
  mkdir -p "$HOME/.local/bin"
  if [ -d "$REPO_DIR/home/local-bin" ]; then
    for s in "$REPO_DIR"/home/local-bin/*; do
      [ -e "$s" ] || continue
      cp -a "$s" "$HOME/.local/bin/"
      chmod +x "$HOME/.local/bin/$(basename "$s")"
      info "~/.local/bin/$(basename "$s")"
    done
  fi
  # screenshot + recording target dirs (hyprland binds)
  mkdir -p "$HOME/Pictures/Screenshots" "$HOME/Videos/Recordings"
}

deploy_home() {
  say "Deploying home-level files (kdeglobals)"
  backup "$HOME/.config/kdeglobals"
  cp -a "$REPO_DIR/home/kdeglobals" "$CFG/kdeglobals"
  info "~/.config/kdeglobals"
}

deploy_kde_scheme() {
  say "Installing KDE color scheme dir"
  mkdir -p "$HOME/.local/share/color-schemes"
  # the `theme` switcher renders the active scheme here; ship a baseline too
  [ -f "$REPO_DIR/kde/color-schemes/Phosphor.colors" ] && \
    cp -a "$REPO_DIR/kde/color-schemes/Phosphor.colors" "$HOME/.local/share/color-schemes/" 2>/dev/null || true
}

# --- deploy theme palettes + render the active theme -------------------------
deploy_themes() {
  say "Installing theme switcher + palettes"
  # themes/ palettes are read by `theme` straight from the repo (PHOSPHOR_REPO),
  # so nothing to copy here — just render the active/default theme now.
  local want="${PHOSPHOR_THEME:-}"
  if [ -z "$want" ] && [ -f "$CFG/phosphor/theme" ]; then want="$(cat "$CFG/phosphor/theme")"; fi
  [ -z "$want" ] && want="phosphor"
  info "rendering theme: $want"
  # run the freshly-installed switcher; PHOSPHOR_REPO points at this checkout
  PHOSPHOR_REPO="$REPO_DIR" "$HOME/.local/bin/wear" "$want" >/dev/null 2>&1 \
    || warn "theme render failed (run: wear $want)"
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

# --- 4. gsettings handled by the `theme` switcher (per-theme) -----------------
# (kept as a no-op fallback if the switcher didn't run)
apply_gsettings() {
  command -v gsettings >/dev/null 2>&1 || return 0
  local S=org.gnome.desktop.interface
  gsettings set $S font-name 'JetBrainsMono Nerd Font 10' 2>/dev/null || true
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
  deploy_local_bin
  deploy_home
  deploy_kde_scheme
  deploy_themes
  apply_icons
  apply_gsettings
  apply_kvantum

  echo
  say "Done! 🟢"
  echo -e "   Backups of anything overwritten are in: ${BOLD}$BACKUP${NC}"
  echo -e "   Switch themes:  ${BOLD}wear${NC} (picker) or ${BOLD}wear <name>${NC} · also ${BOLD}Super+Shift+T${NC}"
  echo -e "   Available:      ${BOLD}wear list${NC}"
  echo -e "   Reload Hyprland: ${BOLD}hyprctl reload${NC} · For Qt/KDE, ${BOLD}log out and back in${NC}."
  echo
  warn "NVIDIA note: hyprland.conf sets NVIDIA env vars. On AMD/Intel, comment out"
  warn "the LIBVA_DRIVER_NAME / __GLX_VENDOR_LIBRARY_NAME / NVD_BACKEND lines."
}

main "$@"
