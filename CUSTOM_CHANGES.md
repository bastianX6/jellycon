# JellyCon Custom Changes

This is a fork of the official jellyfin/jellycon addon (https://github.com/jellyfin/jellycon). It is maintained in parallel to the official plugin: whenever the official plugin releases a new version, the maintainer pulls upstream changes into this fork and re-applies custom changes on top.

The custom changes add animated GIF preview thumbnails and enhanced media filters to improve the Kodi browsing experience.

## How to Sync with Upstream

**Official repo:** https://github.com/jellyfin/jellycon  
**Current base version:** official v1.0.2

When the official jellycon releases a new version, follow this workflow:

1. Ensure the upstream remote is configured:
   ```bash
   git remote add upstream https://github.com/jellyfin/jellycon.git
   ```

2. Fetch the latest changes from upstream:
   ```bash
   git fetch upstream
   ```

3. Rebase or merge the upstream release tag/master into this branch:
   ```bash
   git rebase upstream/<tag>   # or
   git merge upstream/master
   ```
   Resolve any conflicts that arise.

4. Re-apply and verify that the custom changes still hold, since upstream may have modified the same functions. Use the checklist below.

**Files/functions to re-verify after each upstream sync:**
- `resources/lib/menu_functions.py`: `show_filter_menu`, `get_filtered_list_url`, `normalize_url_for_filtering`
- `resources/lib/dir_functions.py`: `is_filterable_list`, `build_filter_menu_url`, get_content mapping (folder/collectionfolder/homevideos extensions)
- `resources/lib/gif_cache.py` (entire file)
- `resources/lib/image_server.py`: GIF proxy endpoint `/gif/{item_id}/{tag}.gif`, port 24276
- `resources/lib/item_functions.py`: `apply_cached_gif_art`, `get_art` (local GIF path usage)
- `resources/language/resource.language.en_gb/strings.po`: strings 30683-30687
- `resources/language/resource.language.es_es/strings.po`: strings 30683-30687
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

## Known Limitations

- GIF animation only works in Kodi list navigation, not in the video player
- GIFs with approximately 12+ HD frames may be truncated by Kodi
- First access to a folder downloads GIFs (progress is shown)
- Kodi must use the JellyCon custom context menu setting (`override_contextmenu`, string 30334) for favorite-toggle menu items (this favorite feature is from the original addon, not our custom changes)