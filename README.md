<div align="center">

# 👕 wear

### One palette. Your entire desktop. Live.

**wear** is a theme engine for Hyprland that repaints *everything* from a
single palette file: Hyprland, Waybar, Kitty, Rofi, Dunst, GTK 3/4, Qt 5/6,
KDE apps, hyprlock, wlogout, satty, your shell & fzf, cursors, icons — even
the animated GPU-shader wallpaper.

Change one colour and the whole desktop follows. Instantly. No logout, no
restart, nothing left un-themed. Ships as a complete desktop with 7 themes —
led by **Phosphor**, a green-on-black CRT look.

![Phosphor desktop](assets/screenshot-1.png)
![Phosphor desktop](assets/screenshot-2.png)

</div>

---

## ⚡ Install — one command

```sh
curl -fsSL https://raw.githubusercontent.com/1ay1/wear/main/bootstrap.sh | bash
```

That's it. Log in to Hyprland (or, if you're already in it, the new look goes
live immediately). Prefer to see what you're running first?

```sh
git clone https://github.com/1ay1/wear.git && cd wear && ./install.sh
```

Start with a different theme: `... | bash -s -- --theme tokyo-night`

The installer:

1. Installs every package the setup needs (repo + AUR via `paru`/`yay`)
2. **Backs up** anything it's about to overwrite → `~/.phosphor-backup/<timestamp>/`
3. Detects your GPU — NVIDIA env vars are enabled only on NVIDIA machines
4. Copies configs into `~/.config` (templates stay in the repo)
5. Installs `wear` + `wear-gui` to `~/.local/bin` and renders the theme
6. Recolours **Papirus** folders and refreshes the icon cache
7. If you're already inside Hyprland: reloads it — the theme is live before
   the prompt returns

Re-running it later is safe: your active theme **and live tweaks survive**.
Stay current with a single command:

```sh
wear update      # git pull + re-deploy, your look untouched
```

> Arch-based distros for the package step; on anything else run
> `./install.sh --skip-pkgs` and install dependencies yourself.

---

## 👕 `wear` — the theme engine

```sh
wear                    # theme picker (Super+Shift+T)
wear tokyo-night        # put on a theme (fuzzy: `wear tokio` works)
wear tweak              # live GUI editor (Super+A)
wear from ~/wall.jpg    # 🪄 generate a theme from an image
wear from-color teal    # 🪄 generate a theme from one colour (hex or name)
wear dark / light       # 🌓 flip ANY theme's polarity, hues preserved
wear doctor --fix       # 🩺 WCAG contrast audit — auto-repairs failures
wear import dracula.yaml # wear any of ~250 base16 community schemes
wear random             # 🎲 dice-roll the whole look (or: accents/shape/feel/bar/popups)
wear undo               # take it back — 30 steps of history
wear show               # truecolor palette swatches in the terminal
```

Switching doesn't just recolour — it **reshapes**: gaps, borders, rounding,
blur, animation feel, layout, bar geometry, fonts, opacity, the wallpaper
shader… every theme is a whole personality.

**Built-in themes:**

| Theme | Personality |
|-------|-------------|
| `phosphor` | sharp CRT — 0 rounding, thin borders, tight gaps, snappy |
| `tokyo-night` | soft neon — big rounding, heavy blur, bouncy pop-in |
| `gruvbox` | cozy retro — chunky 4px borders, master layout, big gaps |
| `catppuccin-mocha` | modern rounded — comfy medium radius |
| `catppuccin-latte` | clean **light** — crisp, low-glow, opaque |
| `nord` | minimal calm — thin, huge gaps, slow gentle fades |
| `rose-pine` | elegant — large pill rounding, graceful pop-in |

---

## 🎛️ Live tweaker (Super+A)

`wear tweak` opens a native **GTK4 / libadwaita** editor — sidebar of
categories, real colour pickers, sliders, searchable dropdowns and font
choosers. Every change hits the whole desktop **as you drag**.

- **Colours** — the full palette on one page: accents, backgrounds, surfaces,
  foregrounds, plus all 16 terminal ANSI colours.
- **Shape** — rounding, border width, inner/outer gaps, tiling layout.
- **Feel** — opacities, blur size/passes/vibrancy, glow, animation speed &
  style, terminal opacity & padding.
- **Bar** — everything: position, height, edge margin (gap to the screen edge
  it hugs) and side margin (left/right) independently, spacing, radius, opacity,
  border, its own font size, workspace count, clock style (seconds / minutes /
  12 h), and a **switch for every module** — window title, CPU, temperature,
  memory, GPU, disk, audio, network, bluetooth, uptime, kernel, tray, power.
  Waybar restarts instantly on each change.
- **Popups** — launcher width & rows (rofi), notification width, corner and
  timeout (dunst).
- **Type** — UI & mono fonts, sizes, weight.
- **System** — dark/light mode, icon theme, cursor theme & size, wallpaper
  shader — all discovered from what's actually installed.

The header has a base-theme switcher, a **randomise-accents shuffle** (colour
theory, not dice: each roll picks a random hue and a harmony strategy —
complementary, triad, analogous, pastel, neon or monochrome — keeps lightness
in the readable band, and re-picks the on-accent text colour by measured
contrast), an undo button, and **Save as new theme**. The menu hides two generators: **Theme from
wallpaper…** and **Theme from a colour…**.

Everything the GUI does is plain CLI underneath — and the CLI is **smart**.
Keys are fuzzy (`radus`→`radius`, `acent`→`accent`), colours can be CSS names
or `#abc`, numbers can be relative, and everything is validated and clamped
against the schema:

```sh
wear set radius +4        # relative nudge
wear set gap_out 2x       # multiply
wear set blur max         # jump to the schema limit
wear set accent hotpink   # 70+ CSS colour names
wear set accent lighter   # ops: lighter/darker/saturate/desaturate[:pct],
wear set accent complement#      complement, invert — applied to the current value
wear set radius default   # un-tweak one key
wear set cursor bibata    # picks fuzzy-match what's actually installed
wear tweaks               # list active tweaks
wear undo                 # revert the last change — 30 steps of history
wear reset                # back to the pure theme
wear save my-look         # snapshot the current look as a real theme
```

Tweaks live in `~/.config/phosphor/overrides.conf` on top of the active theme
and are cleared when you switch base themes (save first to keep them).
No GUI session? `wear tweak` falls back to an equivalent rofi menu.

---

## 🪄 Generate a theme from anything

Don't design — generate. `wear` ships a colour engine (pure-awk HSL math) that
turns **one seed colour** into a complete, balanced palette: tinted background
ramp, readable foregrounds, a harmonised accent trio (±30° hues), and a full
ANSI-16 set.

```sh
wear from ~/Pictures/wall.jpg          # theme from a wallpaper / photo
wear from-color 7c3aed                 # theme from one hex colour
wear from-color ff7b39 sunset --light  # named, light-mode
```

`wear from <image>` quantises the image, scores candidates by saturation,
picks the most vivid non-grey as the seed, pulls the accent trio from the
image's own hues when it's colourful enough (±30° harmonies otherwise), and
blends the background toward the image's actual darkest tone — so the theme
*feels* like the picture. Generated themes are first-class: real
`themes/<name>.theme` files you can tweak, save and keep. Don't like it?
`wear undo`.

---

## 🌓 Any theme, both polarities

Every theme works in dark **and** light — `wear` re-derives the whole palette
for the other polarity on the fly, keeping every hue:

```sh
wear light     # light version of whatever you're wearing
wear dark      # back to the dark side
wear toggle    # flip (bind it, cron it at sunset, whatever)
```

Backgrounds/foregrounds mirror their lightness, accents and ANSI colours are
nudged into the readable band for the new polarity. It's applied as live
tweaks — `wear undo` reverts, `wear save <name>` keeps it forever.

## 🩺 Built-in accessibility doctor

`wear doctor` audits the active look against **WCAG AA**: real contrast
ratios (proper sRGB linearisation) for every text/background pairing the
desktop actually renders — body text, panels, cards, accent fills,
error/warning colours, terminal comments — plus GPU-cost warnings.

```sh
wear doctor        # audit — ✓/✗ per pairing with the measured ratio
wear doctor --fix  # walk failing colours' lightness (hue untouched) until they pass
```

Every theme that ships with wear passes all checks.

## 📦 base16 in, base16 out

There are ~250 community [base16 / tinted-theming](https://github.com/tinted-theming/schemes)
schemes. All of them are wearable:

```sh
wear import dracula.yaml          # local file — or paste a github URL:
wear import https://github.com/tinted-theming/schemes/blob/spec-0.11/base16/dracula.yaml
wear export > my-look.yaml        # share the ACTIVE look as base16
```

Import maps base00–0F onto the full palette (accent trio = the three most
saturated slots, on-accent chosen by measured contrast) and writes a
first-class `.theme` you can tweak, flip and save.

---

## 🎨 One palette drives every engine

You never recolour GTK or Qt by hand. GTK apps sit on a neutral base
(`adw-gtk3`/Adwaita, auto light↔dark) and Qt apps on Fusion — and `wear`
**generates** the full colour set for both from your palette: libadwaita named
colours, headerbars, buttons, switches, checks, sliders, tabs, menus,
hover/pressed shades (computed mixes of your accent), the complete Qt5/Qt6
scheme, and the KDE colour scheme.

Change `accent` once → GTK apps, Qt apps, the terminal, the bar, notifications
and window borders all follow. Instantly.

Your shell follows too — every switch renders `~/.config/phosphor/colors.sh`
(the palette as `PHOS_*` vars + a matching `FZF_DEFAULT_OPTS`):

```sh
[ -f ~/.config/phosphor/colors.sh ] && . ~/.config/phosphor/colors.sh
```

---

## ✍️ Make your own theme

A theme is one flat file of `key="value"` pairs — ~26 colours (hex, no `#`)
plus structure:

```sh
cp themes/nord.theme themes/my-theme.theme
$EDITOR themes/my-theme.theme
wear my-theme
```

Core structural keys:

| Key | Controls |
|-----|----------|
| `radius` | corner rounding everywhere |
| `border_width` | frame thickness (windows, widgets, inputs) |
| `gap_in` / `gap_out` | inner / outer window gaps |
| `layout` | `dwindle` or `master` |
| `opacity_active` / `_inactive` | window opacity |
| `blur_size` / `_passes` / `blur_vibrancy` | Hyprland + hyprlock blur |
| `glow` | shadow / text-shadow intensity (0 flat … 1 neon) |
| `anim_speed` / `anim_bezier` / `anim_style` | animation feel |
| `bar_position` / `bar_height` / `bar_margin` / `bar_radius` | waybar shape |
| `font_ui` / `font_mono` + sizes / weight | typography |
| `term_opacity` / `term_padding` | kitty |
| `mode` / `icon_theme` / `cursor_theme` / `cursor_size` | system |
| `wallpaper_shader` | animated GLSL wallpaper (neowall) |

Every colour-bearing config in `config/` is a `*.tmpl` template with `{{key}}`
placeholders; `wear` renders them into `~/.config`.

---

## 🖥️ What's in the box

| Component | What it themes |
|-----------|----------------|
| `hypr/` | Hyprland WM, hyprlock, hypridle, screenshot & recording scripts |
| `waybar/` | Status bar (+ GPU module) |
| `kitty/` | Terminal |
| `rofi/` | Launcher + pickers |
| `dunst/` | Notifications |
| `gtk-3.0/`, `gtk-4.0/` | GTK apps — full palette-generated theming |
| `qt5ct/`, `qt6ct/`, `Kvantum/` | Qt apps |
| `kde/` | KDE colour scheme (Dolphin, Kate, …) |
| `neowall/` | 40+ animated GPU-shader wallpapers |
| `wlogout/` | Logout menu |
| `satty/` | Screenshot annotator |
| `home/local-bin/` | `wear`, `wear-gui`, `shader-switch.sh` |
| `themes/` | The palette files |

Defaults: **JetBrainsMono Nerd Font** · **Bibata-Modern-Amber** cursor ·
**Papirus-Dark** icons (green folders).

---

## 🔧 Notes

- **NVIDIA:** `hypr/hyprland.conf` sets NVIDIA env vars. On AMD/Intel comment
  out the `LIBVA_DRIVER_NAME`, `__GLX_VENDOR_LIBRARY_NAME` and `NVD_BACKEND` lines.
- **Qt/KDE:** log out and back in once after install so
  `QT_QPA_PLATFORMTHEME=qt6ct` applies to Qt6 apps.
- **Best GTK3 result:** install `adw-gtk-theme` (the installer does) — `wear`
  auto-selects it as the neutral base.
- **Skip packages:** `PHOSPHOR_SKIP_PKGS=1 ./install.sh` deploys configs only.
- **Restore:** everything overwritten is in `~/.phosphor-backup/<timestamp>/`.
- **Repo location:** `wear` finds the repo at `~/wear` (or set
  `PHOSPHOR_REPO=/path`).

<details>
<summary><b>Full <code>wear</code> CLI reference</b></summary>

```
wear                    theme picker (rofi / fzf)
wear <name>             switch to a theme (fuzzy — wear tokio, wear gruv)
wear list | current     list themes / print active
wear reload             re-apply (after editing a palette)
wear dark|light|toggle  flip polarity, hues preserved
wear tweak [--rofi]     live editor (GUI, or rofi menu)
wear set <key> <value>  smart live override (fuzzy keys, relative values,
                        colour names & ops, validated + clamped)
wear unset <k>          drop one override (also: wear set <k> default)
wear tweaks             list active overrides
wear reset              clear all overrides
wear undo               revert last change (30-step history)
wear save <name>        save current look as a new theme
wear random-accents     shuffle the accent trio
wear doctor [--fix]     WCAG AA contrast audit (+ auto-repair)
wear import <yml|url>   import a base16 scheme
wear export             active look as base16 yaml
wear from <image> [name] [--light]      generate theme from an image
wear from-color <c> [name] [--light]    generate theme from a colour
wear show               truecolor palette swatches
wear schema|values|get|options          machine-readable (drives the GUI)
```

</details>

---

## 📦 Dependencies

Installed automatically: `hyprland hyprlock hypridle waybar dunst rofi kitty
qt5ct qt6ct kvantum papirus-icon-theme bibata-cursor-theme
ttf-jetbrains-mono-nerd satty grim slurp wf-recorder jq fzf hyprpicker wlogout
brightnessctl playerctl pipewire wireplumber wl-clipboard cliphist
polkit-gnome libnotify python-gobject gtk4 libadwaita adw-gtk-theme
imagemagick` · AUR: `neowall-git papirus-folders`

---

<div align="center"><sub>Take the red pill. 🔴 → 🟢</sub></div>
