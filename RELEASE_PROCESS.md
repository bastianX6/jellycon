# JellyCon Custom Fork — Release Process

This document is the authoritative, procedural guide for releasing the JellyCon custom fork. It is written so that a person or an LLM with no prior conversation context can perform, verify, and troubleshoot a release safely.

## 0. Overview

Every release involves **two repositories**. Both repositories are owned by `bastianX6`, but they have different roles and must not be treated as interchangeable.

1. **Source addon repository**: `https://github.com/bastianX6/jellycon.git`
   - Working branch: `release/1.0.3-beta`.
   - This is a fork of the official repository at `https://github.com/jellyfin/jellycon`.
   - It contains the addon source code and custom features, including media filters, the Favorites menu, and animated GIF preview thumbnails.
   - The release version is maintained in `release.yaml`.
   - The source repository is where code and release metadata are changed.

2. **Kodi repository**: `https://github.com/bastianX6/jellycon-repo.git`
   - Branch: `main`.
   - Published by GitHub Pages at `https://bastianx6.github.io/jellycon-repo/`.
   - This is a static Kodi addon repository in the canonical Kodi layout. Kodi installs addons from this published repository, not directly from the source repository.
   - It contains the root `addons.xml`, its `addons.xml.md5` checksum, an `index.html` in every browsable folder, the versioned plugin zip, and the `repository.jellycon` addon.

The source repository may also have a GitHub release. Such a release is optional and is not required for Kodi installation. The primary user installation path is the Kodi repository served by GitHub Pages.

### Release variables

Use these variables while following the procedure:

- `<NEW>` is the new numeric release version, such as `1.0.11`.
- `<OLD>` is the currently published numeric release version, such as `1.0.10`.
- The source `release.yaml` version is `<NEW>~beta`.
- The generated and published Kodi addon version is `<NEW>~beta+py3`.
- `<temp>` is a scratch directory used for a fresh clone of `jellycon-repo`.

Do not literally put angle brackets into filenames or version fields. Replace each placeholder with the actual value for the release.

## 1. Why a special version format (CRITICAL)

Kodi's addon version parser, `CAddonVersion`, uses Debian-style versioning:

```text
[epoch:]upstream[-revision]
```

The hyphen (`-`) is a **reserved separator** in this grammar. A version such as `1.0.3-beta+py3` is interpreted as upstream `1.0.3` plus revision `beta+py3`. Kodi does not handle this form gracefully and can crash while installing the addon. This is the known issue documented in `xbmc/xbmc#28057`.

The fork therefore uses tilde notation for prereleases:

```text
release.yaml:       1.0.3~beta
generated addon.xml: 1.0.3~beta+py3
```

The build script appends `+py3` to the generated addon version. The tilde is valid Debian-style prerelease notation and sorts the beta before the corresponding final numeric release.

**Mandatory rule:** never use a hyphen in the version string in `release.yaml`. Use `~beta`, or use a plain numeric version such as `1.1.0`. This applies even if a historical Git tag used a hyphen.

## 2. Current state (as of writing)

- The source repository branch is `release/1.0.3-beta`.
- The source version is `1.0.10~beta`.
- The Kodi repository `main` branch has `plugin.video.jellycon-1.0.10~beta+py3.zip` published.
- The Kodi repository also contains the `repository.jellycon` addon at version `1.0.0`. This repository addon is stable and does not change for every JellyCon plugin release.

Before a future release, verify the actual current version rather than relying only on this section. The current version determines `<OLD>` and the next version determines `<NEW>`.

## 3. Step-by-step release procedure

### Phase A — Prepare the source repo

Perform this phase in `/Users/bastian/DEV/others/jellycon`.

#### 1. Confirm the repository and branch

Run:

```sh
cd /Users/bastian/DEV/others/jellycon
git branch --show-current
git status
```

Expected branch output:

```text
release/1.0.3-beta
```

The status output must show a clean worktree, apart from the normal branch tracking line. Do not proceed if the branch is different or if unrelated changes are present. Do not discard changes made by another person or process; stop and resolve the worktree state first.

#### 2. Update `release.yaml`

Open the exact file:

```text
/Users/bastian/DEV/others/jellycon/release.yaml
```

Make these changes:

- Change the version to `version: '<NEW>~beta'`.
- Update the `changelog:` block, which is a YAML block scalar using `|-`.
- Keep a `New Features` section and a `Bug Fixes` section, matching the existing style.
- Describe changes in this release only, with one bullet per item.
- Do not change `dependencies:`.
- Do not put a hyphenated prerelease such as `1.0.11-beta` in the version field.

A representative shape is:

```yaml
version: '<NEW>~beta'
changelog: |-
  New Features
  - Describe the new feature included in this release.

  Bug Fixes
  - Describe the bug fix included in this release.
dependencies:
  # Keep the existing dependencies exactly as they are.
```

The exact existing dependency contents and project formatting take precedence over this illustrative excerpt. Do not replace the complete file with the example.

#### 3. Build the addon

From the source repository root, run:

```sh
python3 build.py --version py3
```

The build performs all of the following:

- Reads version and changelog data from `release.yaml`.
- Regenerates `/Users/bastian/DEV/others/jellycon/addon.xml` from `.config/template.xml`.
- Writes the generated addon version as `<NEW>~beta+py3`.
- Injects the changelog into the generated `<news>` element.
- Creates `/Users/bastian/DEV/others/jellycon/plugin.video.jellycon+py3.zip`.

Both generated root files, `addon.xml` and `plugin.video.jellycon+py3.zip`, are Gitignored. They are build artifacts and must not be committed to the source repository.

Verify the generated metadata:

```sh
```

The matching line must contain the plugin id and the new generated version, for example:

```xml
<addon id="plugin.video.jellycon" ... version="<NEW>~beta+py3" ...>
```

If the generated version contains a hyphen, stop, correct `release.yaml`, and rebuild before continuing.

#### 4. Commit and push the source change

Stage only the release metadata file:

```sh
git add release.yaml
```

The staging status must show `release.yaml` and must not show root `addon.xml` or `plugin.video.jellycon+py3.zip`. A successful push reports that `release/1.0.3-beta` was updated on `origin`.

### Phase B — Publish to the Kodi repository (`jellycon-repo`)

Use a fresh clone to avoid stale files, old generated metadata, or an accidentally wrong branch. The following scratch path is available in this environment, but any disposable temporary directory is acceptable.

```sh
rm -rf /var/folders/ys/6x8h04kn76n2k6t59r_r8gxr0000gn/T/opencode/jr
git clone https://github.com/bastianX6/jellycon-repo.git /var/folders/ys/6x8h04kn76n2k6t59r_r8gxr0000gn/T/opencode/jr
cd /var/folders/ys/6x8h04kn76n2k6t59r_r8gxr0000gn/T/opencode/jr
```

The branch must be `main`. In the commands below, `<temp>` means this clone's root directory.

#### 1. Remove the old plugin zip

Run:

```sh
```

Use the filename that actually exists in the freshly cloned repository. The old zip must not remain alongside the new zip, because Kodi's repository metadata and directory listing must describe one current plugin version.

#### 2. Copy in the newly built zip

Run:

```sh
cp /Users/bastian/DEV/others/jellycon/plugin.video.jellycon+py3.zip plugin.video.jellycon/plugin.video.jellycon-<NEW>~beta+py3.zip
```

The source build artifact has the unversioned filename `plugin.video.jellycon+py3.zip`; the Kodi repository copy must have the versioned filename `plugin.video.jellycon-<NEW>~beta+py3.zip`.

#### 3. Update the plugin folder `addon.xml`

Edit:

```text
<temp>/plugin.video.jellycon/addon.xml
```

On the root `<addon id="plugin.video.jellycon" ...>` element, change only its `version` attribute to:

```text
<NEW>~beta+py3
```

Do not change dependencies, extensions, metadata, or any other attributes.

#### 4. Update the plugin folder `index.html`

Edit:

```text
<temp>/plugin.video.jellycon/index.html
```

Change both the link `href` and the visible link text from the old zip filename to:

```text
plugin.video.jellycon-<NEW>~beta+py3.zip
```

The link line must end with a **trailing space after the closing `</a>` tag**. For example, the relevant line must have this exact structure, including the final space before the newline:

```html
<a href="plugin.video.jellycon-<NEW>~beta+py3.zip">plugin.video.jellycon-<NEW>~beta+py3.zip</a> 
```

This trailing space is critical. Kodi's `HTTPDirectory.cpp` parser uses a regex equivalent to:

```regex
<a href="([^"]*)"[^>]*>\s*(.*?)\s*</a>(.+?)(?=<a|</tr|$)
```

The `(.+?)` after `</a>` requires at least one character. A newline alone is not matched because `.` does not match `\n`. Without the trailing space, Kodi can list zero files in the folder.

#### 5. Update the plugin changelog

Edit:

```text
<temp>/plugin.video.jellycon/changelog.txt
```

Change the release heading to:

```text
<NEW>~beta+py3
```

Keep the feature and bug-fix bullets appropriate to this release. Do not change the stable repository addon changelog.

#### 6. Update root `addons.xml`

Edit:

```text
<temp>/addons.xml
```

Find the `<addon id="plugin.video.jellycon" ...>` element and set its `version` attribute to:

```text
<NEW>~beta+py3
```

Leave the `<addon id="repository.jellycon" ...>` entry untouched. The repository addon must remain version `1.0.0`.

The safest way to update XML while preserving the XML declaration is:

```sh
python3 - <<'PY'
import xml.etree.ElementTree as ET

path = "addons.xml"
root = tree.getroot()

for addon in root.findall("addon"):
    if addon.get("id") == "plugin.video.jellycon":
        addon.set("version", "<NEW>~beta+py3")
        break
else:
    raise SystemExit("plugin.video.jellycon entry not found")

tree.write(path, encoding="utf-8", xml_declaration=True)
PY
```

Inspect the diff afterward. The command may normalize XML serialization; the resulting file must still contain the plugin entry at the new version, the repository entry at `1.0.0`, and the XML declaration `<?xml version='1.0' encoding='utf-8'?>`.

#### 7. Regenerate and verify `addons.xml.md5`

From the Kodi repository root, run exactly:

```sh
python3 -c "import hashlib;print(hashlib.md5(open('addons.xml','rb').read()).hexdigest())" > addons.xml.md5
md5 -q addons.xml
cat addons.xml.md5
```

The last two outputs must be identical. The checksum file contains the digest followed by a newline.

#### 8. Validate the new zip and its internal metadata

Run:

```sh
unzip -t plugin.video.jellycon/plugin.video.jellycon-<NEW>~beta+py3.zip
unzip -p plugin.video.jellycon/plugin.video.jellycon-<NEW>~beta+py3.zip plugin.video.jellycon/addon.xml | grep 'addon id'
```

The first command must finish with no errors. The second command must show the internal addon version `<NEW>~beta+py3`.

#### 9. Commit and push the Kodi repository

Review all changes, then commit and push:

```sh
```

The diff should include removal of the old plugin zip, addition of the new plugin zip, and updates to the plugin `addon.xml`, plugin `index.html`, plugin `changelog.txt`, root `addons.xml`, and root `addons.xml.md5`. It must not modify the `repository.jellycon` addon version or unrelated files.

#### 10. Wait for GitHub Pages

GitHub Pages may briefly report `building` after the push. Poll the Pages deployment status with the authenticated GitHub CLI:

```sh
for i in $(seq 1 12); do
  status=$(gh api repos/bastianX6/jellycon-repo/pages --jq '.status')
  printf 'attempt %s: %s\n' "$i" "$status"
  [ "$status" = built ] && break
  sleep 10
```

The expected final status is:

```text
built
```

If the loop ends without `built`, do not declare the release complete. Inspect the Pages response and repository Actions/deployment status before proceeding.

### Phase C — Verify the published release (mandatory)

These checks must target the GitHub Pages URLs, not only the local clone. Replace `<NEW>` and `<OLD>` with the actual versions.

#### 1. New zip returns HTTP 200

```sh
curl -sI https://bastianx6.github.io/jellycon-repo/plugin.video.jellycon/plugin.video.jellycon-<NEW>~beta+py3.zip
```

Confirm an HTTP `200` response. Redirects are acceptable only if the final response is `200`; use `curl -sIL` if the headers need to be followed explicitly.

#### 2. Old zip returns HTTP 404

```sh
curl -sI https://bastianx6.github.io/jellycon-repo/plugin.video.jellycon/plugin.video.jellycon-<OLD>~beta+py3.zip
```

Confirm an HTTP `404` response. A cached `200` means Pages has not published the deletion yet or the wrong old filename was tested.

#### 3. Published plugin directory has the exact link

Fetch the directory listing:

```sh
curl -s https://bastianx6.github.io/jellycon-repo/plugin.video.jellycon/
```

The body must contain a link whose `href` and text are both `plugin.video.jellycon-<NEW>~beta+py3.zip`. The link line must include a trailing space after `</a>`. Inspect exact whitespace with:

```sh
python3 - <<'PY'
import urllib.request

url = "https://bastianx6.github.io/jellycon-repo/plugin.video.jellycon/"
body = urllib.request.urlopen(url).read().decode()
for line in body.splitlines(keepends=True):
    if "plugin.video.jellycon-" in line:
        print(repr(line))
PY
```

The representation should show `</a> ` before the line-ending sequence.

#### 4. Published `addons.xml` has both required entries

```sh
curl -s https://bastianx6.github.io/jellycon-repo/addons.xml
```

Confirm that the plugin entry has version `<NEW>~beta+py3` and that the `repository.jellycon` entry remains at version `1.0.0`.

#### 5. Published checksum matches published XML

Run:

```sh
curl -s https://bastianx6.github.io/jellycon-repo/addons.xml -o /tmp/jellycon-addons.xml
curl -s https://bastianx6.github.io/jellycon-repo/addons.xml.md5 -o /tmp/jellycon-addons.xml.md5
md5 -q /tmp/jellycon-addons.xml
cat /tmp/jellycon-addons.xml.md5
```

The digest printed by `md5 -q` must exactly equal the content of `/tmp/jellycon-addons.xml.md5`.

#### 6. Download and validate the published zip

```sh
curl -sS https://bastianx6.github.io/jellycon-repo/plugin.video.jellycon/plugin.video.jellycon-<NEW>~beta+py3.zip -o /tmp/plugin.video.jellycon-<NEW>~beta+py3.zip
unzip -t /tmp/plugin.video.jellycon-<NEW>~beta+py3.zip
unzip -p /tmp/plugin.video.jellycon-<NEW>~beta+py3.zip plugin.video.jellycon/addon.xml | grep 'addon id'
```

The archive test must report no errors, and the internal addon XML must report version `<NEW>~beta+py3`.

#### 7. Simulate Kodi's HTTP directory parser

Run the following exact parser simulation against the served folder listing:

```sh
python3 -c "import re,urllib.request; h=urllib.request.urlopen('https://bastianx6.github.io/jellycon-repo/plugin.video.jellycon/').read().decode(); print(re.findall(r'<a href=\"([^\"]*)\"[^>]*>\s*(.*?)\s*</a>(.+?)(?=<a|</tr|$)', h, re.IGNORECASE|re.DOTALL))"
```

The printed list must contain the new zip filename. If it prints an empty list, the published `index.html` almost certainly lacks the required character after `</a>` or Pages has not finished serving the latest commit.

### Phase D — Optional: GitHub Release in the source repo

A GitHub release is optional and is not used by Kodi's repository installation path. Create one only when a downloadable source-repository release asset is wanted.

First inspect existing tags and releases so the naming convention is consistent:

```sh
```

Historically, this repository had no `v` prefix and used a tag such as `1.0.3-beta`. Prefer the Kodi-valid tilde notation for new releases: `<NEW>~beta`.

If the build process has also created the checksum asset `plugin.video.jellycon+py3.zip.sha256`, create the release with:

```sh
  plugin.video.jellycon+py3.zip \
  plugin.video.jellycon+py3.zip.sha256 \
  --repo bastianX6/jellycon \
  --title <NEW>~beta \
  --notes-file <notes>
```

Replace `<notes>` with an existing release-notes file. This phase must not be mistaken for publishing the Kodi repository; it is supplementary.

## 4. How users install (embedded devices, per official Jellyfin docs method)

The primary installation path uses Kodi's file manager and the static repository URL. The user must have network access to GitHub Pages.

1. In Kodi, open **File manager** → **Add source**.
2. Enter `https://bastianx6.github.io/jellycon-repo/` as the source URL. Use `JellyCon Repo` as the source name.
3. Open **Add-ons** → **Install from zip file**.
4. Select the `JellyCon Repo` source and install `repository.jellycon-1.0.0.zip`.
5. If Kodi prompts about unknown sources, enable **Unknown sources** and repeat the installation.
6. Open **Add-ons** → **Install from repository** → **JellyCon Repository** → **JellyCon**.

An alternative is to browse into `plugin.video.jellycon/` in the file source and install the plugin zip directly. Direct installation does not provide the repository's normal update mechanism.

For the custom context-menu features, enable the addon setting `override_contextmenu` (setting string `30334`). Its default is `true`, but verify it if custom context menu items such as **Set Favorite** and **Unset Favorite** are missing.

## 5. The canonical Kodi repository layout (reference)

The Kodi repository must have this layout at its published root:

```text
<repo root>/
  addons.xml
  addons.xml.md5
  index.html                     <- links to plugin.video.jellycon/ and repository.jellycon/ (folders)
  plugin.video.jellycon/
    addon.xml
    changelog.txt
    index.html                   <- links to the plugin zip
    plugin.video.jellycon-<VERSION>.zip
  repository.jellycon/
    addon.xml
    changelog.txt
    icon.png
    index.html                   <- links to repository.jellycon-1.0.0.zip
    repository.jellycon-1.0.0.zip
```

The `repository.jellycon/addon.xml` repository extension block is expected to point at the GitHub Pages root as follows:

```xml
<extension point="xbmc.addon.repository" name="JellyCon Repository">
  <dir>
    <info compressed="false">https://bastianx6.github.io/jellycon-repo/addons.xml</info>
    <checksum verify="false">https://bastianx6.github.io/jellycon-repo/addons.xml.md5</checksum>
    <datadir zip="true">https://bastianx6.github.io/jellycon-repo/</datadir>
  </dir>
</extension>
```

The `datadir` is the directory prefix Kodi uses when constructing plugin download URLs. With addon folders at the repository root, the Pages root shown above is correct.

Every browsable folder must have an `index.html`. Every `index.html` link line must end with a trailing space after `</a>` because this is required by Kodi's HTTP directory parser. The root listing must link to `plugin.video.jellycon/` and `repository.jellycon/`; the plugin listing must link to the current versioned plugin zip; and the repository listing must link to `repository.jellycon-1.0.0.zip`.

## 6. Troubleshooting (based on issues encountered and fixed)

### Kodi install crashes

**Symptom:** Kodi crashes during addon installation.

**Likely cause:** A version string contains a hyphen, for example `1.0.3-beta`. Kodi interprets the hyphen as the Debian-style upstream/revision separator and can fail in `CAddonVersion` handling.

**Fix:** Change the source version to `1.0.3~beta` or the appropriate `<NEW>~beta`, rebuild with `python3 build.py --version py3`, verify the generated version is `<NEW>~beta+py3`, and republish all Kodi metadata and the zip.

### Kodi shows zero files when browsing the repository

**Symptom:** Kodi can reach the repository folder but displays no files.

**Likely cause:** A link line in `index.html` is missing the trailing space after `</a>`.

**Fix:** Add at least one character after `</a>`, specifically the required trailing space, to every link line. Recheck the raw served HTML with `repr`, wait for Pages to rebuild, and restart Kodi because HTTP directory listings and related caches can be per-session.

### 404 when installing the addon after installing the repository addon

**Symptom:** The repository addon installs, but selecting JellyCon produces a 404 for the plugin zip.

**Likely cause:** The `datadir` in `repository.jellycon/addon.xml` does not match the actual location of the addon folders.

**Fix:** If `plugin.video.jellycon/` and `repository.jellycon/` are at the repository root, use:

```xml
<datadir zip="true">https://bastianx6.github.io/jellycon-repo/</datadir>
```

If addon folders are instead under `zips/`, use the corresponding `zips/` URL. Kodi constructs the download URL as:

```text
<datadir>/<addon-id>/<addon-id>-<version>.zip
```

Verify that the resulting URL exactly matches the published path and filename, including `~beta+py3`.

### “Can't connect” when adding the source

**Symptom:** Kodi cannot connect to the source URL or cannot browse it.

**Likely causes:** GitHub Pages returns 404 for folders without `index.html`, or the source URL does not have its trailing slash.

**Fix:** Use the exact URL `https://bastianx6.github.io/jellycon-repo/`, including the trailing slash. Ensure the repository root and every browsable folder have an `index.html`, and confirm the Pages site is serving the current `main` commit.

### Addon will not start: `ImportError: circular import`

**Symptom:** The addon fails to start with a circular-import error.

**Cause and fix:** Do not import `image_server` from `item_functions`; those modules are mutually dependent. `item_functions.py` must define its own constant:

```python
PORT_NUMBER = 24276
```

`gif_cache.py` must import only from `utils`, the Python standard library, `requests`, and `xbmc*` modules. This is a source-code issue, not a repository metadata issue.

### GIF thumbnails show only the first frame

**Symptom:** An animated GIF preview appears as a static first frame.

**Likely causes:** The URL Kodi loads does not end in `.gif`, or the GIF is being served over HTTP. Kodi can flatten HTTP images.

**Fix:** Use local file paths ending in `.gif`. The addon downloads GIFs to its profile `gifs/` directory. Kodi animates local GIFs when the extension is preserved, and the implementation disables Kodi's texture cache for them.

### Filters return empty results

**Symptom:** A filter query returns no items even though matching items exist.

**Fixes:**

- Pass `IsPlayed` as a Python boolean, `True` or `False`, not as a lowercase string.
- Ensure `IncludeItemTypes` includes `Video` for home-video content.
- Normalize `/Shows/...` URLs to `/Users/{userid}/Items`; `/Shows/...` endpoints do not accept `Filters/IsPlayed` in the required way.

### Favorites list is empty

**Symptom:** Favorites do not appear.

**Cause:** The Favorites query specifies `IncludeItemTypes`. Jellyfin then returns only those exact types, which can exclude `Video` items.

**Fix:** Omit `IncludeItemTypes` from the Favorites query.

### Addon settings change is not applied

**Symptom:** A setting change, including `override_contextmenu`, appears to have no effect.

**Fix:** Restart Kodi. HTTP directory listings and some addon caches are retained for the current session.

## 7. Checklist before finishing a release

- [ ] Source `release.yaml` version bumped to `<NEW>~beta` and committed/pushed on `release/1.0.3-beta`.
- [ ] New zip built and its internal `addon.xml` version is `<NEW>~beta+py3`.
- [ ] Kodi repository old zip removed and new zip added.
- [ ] Kodi repository plugin `addon.xml`, `index.html`, and `changelog.txt` updated.
- [ ] Root `addons.xml` updated for the plugin while `repository.jellycon` remains `1.0.0`.
- [ ] `addons.xml.md5` regenerated and matches `addons.xml`.
- [ ] All relevant `index.html` links retain a trailing space after `</a>`.
- [ ] Kodi repository changes committed and pushed to `main`.
- [ ] GitHub Pages status is `built`.
- [ ] Published new zip returns HTTP 200.
- [ ] Published old zip returns HTTP 404.
- [ ] Published `addons.xml` contains the new plugin version and repository version `1.0.0`.
- [ ] Published checksum matches the fetched published XML.
- [ ] Downloaded published zip passes `unzip -t` and has the expected internal version.
- [ ] Kodi parser simulation lists the new zip.
- [ ] `CUSTOM_CHANGES.md` and `RELEASE_PROCESS.md` are kept up to date.
