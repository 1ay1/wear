<div align="center">

# 🟢 PHOSPHOR

### A themeable Hyprland desktop — switch EVERYTHING with one command

One palette drives your **entire** desktop — Hyprland, Waybar, Kitty, Rofi,
Dunst, GTK 3/4, Qt 5/6, KDE apps, hyprlock, satty, wlogout, cursors, icons, and
an animated GPU-shader wallpaper. Ships with **7 themes** (Phosphor, Tokyo
Night, Gruvbox, Catppuccin Mocha & Latte, Nord, Rosé Pine) and a `theme`
switcher that repaints all of it live. Nothing left un-themed.

![Phosphor desktop](assets/screenshot-1.png)
![Phosphor desktop](assets/screenshot-2.png)

</div>

---

## ⚡ One-command install

```sh
git clone https://github.com/1ay1/phosphor-hypr.git && cd phosphor-hypr && ./install.sh
```

or, straight from the web:

```sh
curl -fsSL https://raw.githubusercontent.com/1ay1/phosphor-hypr/main/bootstrap.sh | bash
```



The installer will:

1. Install every package the theme needs (repo + AUR via `paru`/`yay`)
2. **Back up** anything it's about to overwrite → `~/.phosphor-backup/<timestamp>/`
3. Copy all configs into `~/.config` (templates stay in the repo)
4. Install the `theme` switcher to `~/.local/bin` and **render the active theme**
5. Recolor **Papirus** folders and refresh the icon cache

---

## 🎨 Switching themes

```sh
wear                  # rofi/fzf picker (also bound to Super+Shift+T)
wear tokyo-night      # switch directly
wear list             # list available themes
wear current          # print the active theme
wear reload           # re-apply (after editing a palette)
```

Switching repaints **and reshapes** everything at once — not just colour but the
whole personality: Hyprland gaps/borders/rounding/blur/animation-feel/layout,
hyprlock, waybar shape & position, rofi geometry, dunst, kitty (font, opacity,
padding), GTK 3/4 (+ theme engine & cursor size), Qt 5/6 (+ widget style),
Kvantum, the KDE colour scheme, satty, wlogout, and the wallpaper shader — then
reloads the running apps.

**Built-in themes** (each a distinct personality, not just a recolour):

| Theme | Personality |
|-------|-------------|
| `phosphor` | sharp CRT — 0 rounding, thin borders, tight gaps, snappy |
| `tokyo-night` | soft neon — big rounding, heavy blur, bouncy pop-in |
| `gruvbox` | cozy retro — chunky 4px borders, master layout, big gaps |
| `catppuccin-mocha` | modern rounded — comfy medium radius, moderate |
| `catppuccin-latte` | clean **light** — crisp, low-glow, opaque |
| `nord` | minimal calm — thin, huge gaps, slow gentle fades |
| `rose-pine` | elegant — large pill rounding, graceful pop-in |

### 🎛️ Live appearance tweaker

Want to nudge one thing without designing a whole theme? Hit **Super+A** (or run
`wear tweak`) to open a native **GTK4 / libadwaita** editor: a sidebar of
categories — **Colours · Shape · Feel · Bar · Type · System** — with real
sliders, colour pickers, dropdowns and font choosers. Every change applies
**instantly** to the whole desktop (it edits on top of the active theme). The
header bar has a base-theme switcher, a randomise-accents shuffle, and **Save
as new theme**.

It covers **everything** — all ~60 properties:

- **Colours** — ONE page for every colour: accents, backgrounds
  (main/alt/dim), surface, overlay, foregrounds (main/dim/faint), on-accent,
  plus the 16 terminal ANSI colours (grouped below the palette).
- **Shape** — rounding, border width, inner/outer gaps, tiling layout.
- **Feel** — window opacities, blur size/passes/vibrancy, glow, animation
  speed & style, terminal opacity & padding.
- **Bar** — position, height, margin, spacing, radius.
- **Type** — UI & mono fonts, sizes, weight.
- **System** — dark/light mode, **icon theme**, **cursor theme & size**, and
  the **wallpaper shader** — discovered from what's actually installed
  (searchable dropdowns).

**Widget engines are invisible plumbing.** GTK apps sit on a neutral base
(adw-gtk3/Adwaita, auto light/dark) and Qt apps on Fusion — both fully
recoloured from your palette. There are no GTK-theme/Qt-style/Kvantum pickers
in the UI because prebuilt themes carry baked-in colours that would fight the
palette. (Power users can still force one: `wear set gtk_theme <name>`,
`wear set qt_style kvantum`, `wear set kvantum_theme <name>`.)

**One palette drives every engine.** You never recolour GTK or Qt yourself:
the default `gtk_theme="auto"` sits GTK on a neutral base (adw-gtk3, or stock
Adwaita) and the switcher *generates* the full colour set from your palette —
libadwaita named colours, headerbars, buttons, switches, checks, sliders,
tabs, menus, hover/pressed shades (computed mixes of your accent), plus the
complete Qt5/Qt6 colour scheme and the KDE scheme. Change `accent` once and
GTK apps, Qt apps, the terminal, the bar, notifications and window borders
all follow — instantly.

Prefer the keyboard? Everything is scriptable via the same CLI (this is exactly
what the GUI drives under the hood):

```sh
wear tweak            # GTK GUI (Super+A) — wear tweak --rofi forces the rofi menu
wear set radius 20    # bump window rounding, live
wear set accent ff8800
wear set gap_out 24
wear tweaks           # show your active tweaks
wear unset radius     # drop one tweak
wear reset            # clear all tweaks, back to the pure theme
wear save my-look     # snapshot the current look as a new theme
```

On a headless / non-GTK session `wear tweak` automatically falls back to a
rofi menu with the same grouped properties (stepper for numbers, swatch strip +
`hyprpicker` eyedropper for colours, `fc-list` font picker).

Tweaks live in `~/.config/phosphor/overrides.conf` and are cleared when you
switch to a different base theme (unless you save them first).

### Add your own

A theme is a single flat file. Copy one and edit the ~26 colour keys:

```sh
cp themes/nord.theme themes/my-theme.theme
$EDITOR themes/my-theme.theme      # hex values, no leading '#'
wear my-theme
```

Every colour-bearing config is a `*.tmpl` template with `{{key}}` placeholders
(and `{{key|rgb}}` for KDE's decimal format); the switcher renders them into
`~/.config` for the palette you pick.

---

## 🖥️ What's included

| Component | What it themes |
|-----------|----------------|
| `hypr/`   | Hyprland WM, hyprlock, hypridle |
| `waybar/` | Status bar (+ GPU script) |
| `kitty/`  | Terminal colors |
| `rofi/`   | App launcher (phosphor.rasi) |
| `dunst/`  | Notifications |
| `gtk-3.0/`, `gtk-4.0/` | GTK apps (Thunar, Nautilus, …) — full phosphor surfaces + green selection |
| `qt5ct/`, `qt6ct/` | Qt apps via Fusion + Phosphor color scheme |
| `Kvantum/` | Optional Kvantum theme |
| `kde/`    | KDE Plasma **Phosphor** color scheme (Dolphin, Kate, …) |
| `neowall/` | Animated GPU-shader wallpaper (matrix/synthwave/phosphor) |
| `wlogout/` | Themed logout menu |
| `satty/` | Screenshot annotation editor (grim+slurp → satty; Ctrl+C copies & saves) |
| `hypr/scripts/` | `screenshot.sh` (grim→satty) & `record.sh` (wf-recorder toggle, NVENC) |
| `~/.local/bin/` | `wear` (switcher) & `shader-switch.sh` (wallpaper picker) |
| `themes/` | Palette files (`*.theme`) — one per theme, ~26 colour keys each |
| `config/**/*.tmpl` | Templates the switcher renders into `~/.config` per theme |

Fonts: **JetBrainsMono Nerd Font** · Cursor: **Bibata-Modern-Amber** · Icons: **Papirus-Dark (green folders)**

---

## 🎨 The theme schema

Each `themes/*.theme` is a flat file of `key="value"` pairs. **Colours** (~26
hex keys, no `#`) plus **structure** (shape, spacing, fonts, blur, animation
feel). Core structural keys:

| Key | Controls |
|-----|----------|
| `radius` | corner rounding everywhere (hypr, waybar, rofi, dunst, satty…) |
| `border_width` | frame thickness (windows, widgets, inputs) |
| `gap_in` / `gap_out` | inner / outer window gaps |
| `layout` | `dwindle` or `master` |
| `opacity_active`/`_inactive` | window opacity |
| `blur_size`/`_passes`/`blur_vibrancy` | Hyprland + hyprlock blur |
| `glow` | shadow / text-shadow intensity (0 flat … 1 heavy neon) |
| `anim_speed`/`anim_bezier`/`anim_style` | animation duration, curve, feel |
| `bar_position`/`bar_height`/`bar_margin`/`bar_radius` | waybar shape |
| `font_ui` / `font_mono` | UI font / terminal font (swapped globally) |
| `font_size_ui`/`font_size_term`/`font_weight` | sizes & weight |
| `term_opacity`/`term_padding` | kitty |
| `cursor_size` | cursor scale |
| `gtk_theme`/`qt_style`/`kvantum_theme` | widget **engines** per theme |
| `icon_theme`/`cursor_theme`/`mode`/`wallpaper_shader` | icons, cursor, dark/light, wallpaper |

---

## 🔧 Notes & customization

- **NVIDIA:** `hypr/hyprland.conf` sets NVIDIA env vars. On AMD/Intel, comment out
  the `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME`, and `NVD_BACKEND` lines.
- **Qt/KDE:** after install, **log out and back in** so `QT_QPA_PLATFORMTHEME=qt6ct`
  and the color scheme apply to Qt6 apps.
- **Skip packages:** `PHOSPHOR_SKIP_PKGS=1 ./install.sh` deploys configs only.
- **Restore:** everything overwritten is in `~/.phosphor-backup/<timestamp>/`.

---

## 📦 Dependencies

Installed automatically: `hyprland hyprlock hypridle waybar dunst rofi kitty
alacritty qt5ct qt6ct kvantum papirus-icon-theme bibata-cursor-theme
ttf-jetbrains-mono-nerd ttf-firacode-nerd satty grim slurp wf-recorder jq fzf hyprpicker wlogout
brightnessctl playerctl pipewire wireplumber dolphin wl-clipboard cliphist
polkit-gnome libnotify` · AUR: `neowall-git catppuccin-gtk-theme-mocha catppuccin-gtk-theme-latte papirus-folders`

---

<div align="center"><sub>Take the red pill. 🔴 → 🟢</sub></div>
