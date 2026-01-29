# Git Worktree Manager — Implementation Plan (Current State)

## Status Snapshot (Implemented)
- **SwiftUI UI is wired to real data** (view model + loader).
- **Worktree row metadata UI** shows live unmerged-commit counts (vs `origin/main`) and working-copy line deltas, with async refresh on startup/activation.
- **Config + git integration** is implemented and tested.
- **Worktree activity sorting** is implemented (HEAD log mtime fallback to worktree mtime).
- **Default + config buttons** are implemented with icon resolution and availability checks.
- **Plugin-based buttons** are implemented (only Ghostty is built-in; others come from repo config).
- **Worktree rows use a left-to-right tint gradient** from a deterministic palette based on the worktree name.
- **Ghostty open/focus** logic is implemented (AX-based focus, fallback open).
- **Ghostty AppleScript launch** is supported (AppleScript first, fallback to `open`).
- **New worktree + delete worktree** flows are implemented (delete includes confirmation dialog; branch kept).
- **Errors are printed to stdout** and shown in the UI.
- **Auto‑quit for smoke checks** via `GWM_AUTO_QUIT=1`.
- **Tests** cover all non‑UI behavior (unit + integration).
- **Config + worktree root overrides** via env vars (for clean experiments).
- **App bundle packaging** via `scripts/build_worky_app.sh` with Worky icon + Info.plist.
- **Busy status IPC + UI** are implemented (UDS socket, CLI commands, and animated busy borders).
- **Active worktree detection** now uses the bundled Ghostty helper script (`open_or_create_ghostty.sh --get-active`) to resolve the active window path, clears the active state on reactivation while the script runs, and shows a bold outline that fades in on the active worktree (icons remain layout-stable with opacity/hover).

## Decisions Locked In
- **Stack:** Swift + SwiftUI (macOS app).
- **Config path:** `~/.config/git_worktree_manager/projects.json`.
- **Config override env:** `GWM_CONFIG_DIR` (directory containing `projects.json`).
- **Project entry:** repo path (worktree or bare). App resolves the underlying git dir via `git rev-parse --git-common-dir`.
- **Worktree discovery:** `git --git-dir <bare> worktree list --porcelain`.
- **New worktree base path:** `~/.worky/<projectName>/<cityName>`.
- **Worktree root override env:** `GWM_WORKTREE_ROOT` (base folder for new worktrees).
- **Branch naming:** same as city/worktree name.
- **Default buttons:** Ghostty only (special handling).
- **Icons:** app bundle, file path, or SF Symbol.
- **Icon file path** can point at a `.app` bundle (icon extracted automatically).
 - **Bundle output:** `dist/Worky.app` using `Resources/WorkyInfo.plist` and `Resources/AppIcon.icns`.
- **Templating vars:** `$WORKTREE`, `$WORKTREE_NAME`, `$PROJECT`, `$PROJECT_NAME`, `$REPO`.
- **Sorting:** most recent activity (HEAD log mtime first, fallback to worktree mtime).
- **Window:** standard app window with hidden title bar; background drag enabled.
- **Busy IPC:** UDS socket at `~/.worky/run/worky.sock` with JSON messages.

## Config + Schema (Implemented)
- **Default config:** empty `apps` and `projects` if no config file exists yet.
- **Home config** (`projects.json`) defines global apps + per-project apps:
  ```json
  {
    "apps": [
      {
        "id": "ghostty",
        "label": "Ghostty",
        "icon": { "type": "file", "path": "/Applications/Ghostty.app" },
        "command": ["open", "-a", "Ghostty.app", "--args", "--working-directory=$WORKTREE"]
      }
    ],
    "projects": [
      {
        "bareRepoPath": "~/Curiosity",
        "apps": [
          {
            "id": "rider",
            "label": "Rider",
            "icon": { "type": "file", "path": "/Applications/Rider.app" },
            "command": ["open", "-a", "Rider", "$WORKTREE/Subito/Subito.slnx"]
          }
        ]
      }
    ]
  }
  ```

## Data Model & Services (Implemented)
- **Core services:**
  - `ProjectsConfigStore`, `GitClient`, `WorktreeActivityReader`
  - `TemplateEngine`, `ButtonBuilder`, `IconResolver`, `CommandExecutor`
  - `GhosttyController`
- **Loader:** `ProjectsLoader` builds project/worktree view data.
- **View model:** `ProjectsViewModel` drives the UI.

## Worktree Discovery (Implemented)
- Parses `git worktree list --porcelain`.
- Filters out the bare repo path from results.
- Normalizes paths for consistency.

## Activity Sorting (Implemented)
- Uses `<gitDir>/logs/HEAD` mtime; fallback to worktree mtime.

## New Worktree Creation (Implemented)
- Path: `~/.worky/<projectName>/<cityName>`.
- City names list is embedded in code (see `Sources/GWMApp/CityNames.swift`).
- Branch name = city name.

## Buttons & Commands (Implemented)
- **Defaults:** Ghostty only (special handling) but now configured globally.
- **Config apps:** defined globally and per project in `projects.json`.
- **Templating:** simple `$VAR` replacement.
- **No availability checks:** buttons are always enabled; missing apps fail at launch time.

## Ghostty Window Focus (Implemented)
- AX lookup of window title `Worky: <ProjectName> / <WorktreeName>`.
- Focus if found; otherwise open a new window.

## Worktree Deletion (Implemented)
- Confirmation dialog in UI.
- `git worktree remove <path>` (branch preserved).

## UI Wiring (Implemented)
- Narrow-first layout kept; wired to real data.
- Error banner in UI + stdout logging.
- Scrollbars hidden (still scrollable).

## Tests (Implemented)
- **Unit:** config parsing, templating, icon resolution, city selection, worktree parsing, activity logic, command execution.
- **Integration:** git worktree add/list/remove using temp repos.
- **View model:** loading behavior.
- **Busy claims:** store behavior (claim/release/expiry).

## Smoke Check / Verification
- Tests: `swift test`
- App startup (auto-quit): `GWM_AUTO_QUIT=1 swift run`

## Known Behavior
- Invalid or missing bare repo paths are skipped (and errors are printed).
- If Accessibility permissions are missing, Ghostty focus falls back to opening a new window.
- If AppleScript launch fails, Ghostty falls back to the `open` launch path.
