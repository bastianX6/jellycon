# JellyCon Custom Changes

This is a fork of the official jellyfin/jellycon addon (https://github.com/jellyfin/jellycon). It is maintained in parallel to the official plugin: whenever the official plugin releases a new version, the maintainer pulls upstream changes into this fork and re-applies custom changes on top.

The custom changes add animated GIF preview thumbnails and enhanced media filters to improve the Kodi browsing experience.

## How to Sync with Upstream

**Official repo:** https://github.com/jellyfin/jellycon  
**Current base version:** official v1.0.2

Use the `sync_upstream.sh` script to pull upstream changes safely:

```bash
./sync_upstream.sh --help
```

### Script Usage

- **Analysis (default):** `./sync_upstream.sh` — fetches and shows what would merge
- **With version check:** `./sync_upstream.sh --version-check` — compares upstream/fork/base versions
- **Merge upstream:** `./sync_upstream.sh --merge --base master` — performs the merge
- **Strict branch check:** `./sync_upstream.sh --merge --require-branch` — errors if not on release/1.0.3-beta

**Options:**
- `--remote <name>` — upstream remote name (default: upstream)
- `--repo <url>` — upstream repo URL (default: https://github.com/jellyfin/jellycon.git)
- `--base <ref>` — branch/ref to sync against (default: master)
- `--fetch` — fetch upstream (on by default)
- `--merge` — perform the merge/rebase
- `--dry-run` — show what would happen (default unless --merge)
- `--version-check` — compare versions
- `--require-branch` — error if not on release/1.0.3-beta

After merge, verify the custom changes still hold using the checklist below.

**Files/functions to re-verify after each upstream sync:**
- `resources/lib/menu_functions.py`: `show_filter_menu`, `get_filtered_list_url`, `normalize_url_for_filtering`
- `resources/lib/dir_functions.py`: `is_filterable_list`, `build_filter_menu_url`, get_content mapping (folder/collectionfolder/homevideos extensions)
- `resources/lib/gif_cache.py` (entire file)
- `resources/lib/image_server.py`: GIF proxy endpoint `/gif/{item_id}/{tag}.gif`, port 24276
- `resources/lib/item_functions.py`: `apply_cached_gif_art`, `get_art` (local GIF path usage)
- `resources/language/resource.language.en_gb/strings.po`: strings 30683-30689
- `resources/language/resource.language.es_es/strings.po`: strings 30683-30689
- `resources/lib/dir_functions.py`: `has_playable_items`, `build_shuffle_all_url`, get_content "Play randomly" insertion
- `resources/lib/play_utils.py`: `play_list_shuffle`
- `resources/lib/functions.py`: `PLAY_LIST_SHUFFLE` mode dispatch
- `resources/settings.xml`: `show_shuffle_all` setting (label 30689)
- `release.yaml`: version notation with `~beta`

## Custom Features

### 1. Media Filters & Favorites Menu

**Description:** Adds a "Filtros" (Filters) entry to all media listings with options for Unwatched/Watched/Favorite/Continue Watching, and a "Favorites" entry in the main menu.

**Files/functions:**
- `resources/lib/menu_functions.py`: `show_filter_menu`, `get_filtered_list_url`, `normalize_url_for_filtering`
- `resources/lib/dir_functions.py`: `is_filterable_list`, `build_filter_menu_url`

**Translation strings:** 30683-30687 (en_gb + es_es)

### 2. Animated GIF Preview Thumbnails

**Description:** Implements a local GIF cache and localhost proxy so Kodi can animate GIF previews stored next to videos on the Jellyfin server. GIFs are downloaded to the addon profile directory under `gifs/` and served via a local HTTP proxy on port 24276.

**Files/functions:**
- `resources/lib/gif_cache.py` (new file)
- `resources/lib/image_server.py`: proxy endpoint `/gif/{item_id}/{tag}.gif`, server port 24276
- `resources/lib/item_functions.py`: `apply_cached_gif_art`, `get_art` (uses local GIF paths when cached)
- `resources/lib/dir_functions.py`: sync download before listing with progress display

**Implementation details:**
- Magic-byte validation (GIF89a/GIF87a)
- Cache reuse for efficiency
- Embedded Tag for proxy authentication

### 3. Content Type Extensions

**Description:** Extends content type mapping for better Kodi integration: `folder`/`collectionfolder` map to `files`, `homevideos` maps to `videos`.

**Files/functions:**
- `resources/lib/dir_functions.py`: get_content mapping

### 4. Play Randomly (Shuffle All)

**Description:** Adds a "Play randomly" (Reproducir aleatoriamente) entry at the top of any media listing that contains playable items. Selecting it re-queries the same Jellyfin list with a random ordering (limited by the `max_play_queue` setting), ignoring sub folders and the Filters/paging UI entries, and plays all resulting items as a Kodi video playlist. Controlled by the `show_shuffle_all` setting (enabled by default).

**Files/functions:**
- `resources/lib/dir_functions.py`: `has_playable_items`, `build_shuffle_all_url`, "Play randomly" insertion in `get_content`
- `resources/lib/functions.py`: `PLAY_LIST_SHUFFLE` mode dispatch
- `resources/lib/play_utils.py`: `play_list_shuffle`
- `resources/settings.xml`: `show_shuffle_all` (default true, label 30689)

**Translation strings:** 30688 (Play randomly), 30689 (setting label)

## Build & Release Notes

**Build command:**
```bash
python3 build.py --version py3
```

**Version notation:** Uses Kodi-valid `~beta` suffix in `release.yaml` (e.g., `1.0.10~beta`) to avoid installation crashes.

**Publishing:** The addon is published to the GitHub Pages Kodi repository at https://bastianX6.github.io/jellycon-repo/. The repository addon is `repository.jellycon`.

**Repository generation requirements:**
- `addons.xml` + `addons.xml.md5` regeneration
- Zip filename: `plugin.video.jellycon-<version>.zip`
- `index.html` listing must have a trailing space after `</a>` (Kodi's HTTP directory parser requires it)

## Notable Bug Fixes

- Version notation `~beta` (Kodi-valid, avoids install crash)
- Circular-import startup fix
- GIF proxy authentication via embedded Tag
- Empty Favorites fix (drop IncludeItemTypes parameter)
- Filter boolean/Video-type/Shows normalization fixes

## Translation Strings Added

| ID   | en_gb | es_es |
|------|-------|-------|
| 30683 | Filters | Filtros |
| 30684 | Unwatched | No vistos |
| 30685 | Watched | Vistos |
| 30686 | Favorites | Favoritos |
| 30687 | Continue Watching | Continuar viendo |
| 30688 | Play randomly | Reproducir aleatoriamente |
| 30689 | Show 'Play randomly' option in lists | Mostrar la opción 'Reproducir aleatoriamente' en los listados |

## Known Limitations

- GIF animation only works in Kodi list navigation, not in the video player
- GIFs with approximately 12+ HD frames may be truncated by Kodi
- First access to a folder downloads GIFs (progress is shown)
- Kodi must use the JellyCon custom context menu setting (`override_contextmenu`, string 30334) for favorite-toggle menu items (this favorite feature is from the original addon, not our custom changes)