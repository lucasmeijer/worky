# Git Worktree Manager — Implementation Plan (Current State)

## Status Snapshot (Implemented)
- **SwiftUI UI is wired to real data** (view model + loader) and no longer uses fake data.
- **Config + git integration** is implemented and tested.
- **Worktree activity sorting** is implemented (HEAD log mtime fallback to worktree mtime).
- **Default + config buttons** are implemented with icon resolution and availability checks.
- **Ghostty open/focus** logic is implemented (AX-based focus, fallback open).
- **New worktree + delete worktree** flows are implemented (delete includes confirmation dialog; branch kept).
- **Errors are printed to stdout** and shown in the UI.
- **Auto‑quit for smoke checks** via `GWM_AUTO_QUIT=1`.
- **Tests** cover all non‑UI behavior (unit + integration).

## Decisions Locked In
- **Stack:** Swift + SwiftUI (macOS app).
- **Config path:** `~/.config/git_worktree_manager/projects.json`.
- **Project entry:** bare repo path (string). Bare repos track worktrees.
- **Worktree discovery:** `git --git-dir <bare> worktree list --porcelain`.
- **New worktree base path:** `~/gwm/<projectName>/<cityName>`.
- **Branch naming:** same as city/worktree name.
- **Default buttons:** Ghostty + Fork.
- **Icons:** app bundle, file path, or SF Symbol.
- **Templating vars:** `$WORKTREE`, `$WORKTREE_NAME`, `$PROJECT`, `$PROJECT_NAME`, `$REPO`.
- **Sorting:** most recent activity (HEAD log mtime first, fallback to worktree mtime).
- **Window:** standard app window with hidden title bar; background drag enabled.

## Config + Schema (Implemented)
- **Home config** (`projects.json`) default:
  ```json
  {
    "projects": [
      { "bareRepoPath": "~/Curiosity.git" },
      { "bareRepoPath": "~/life" }
    ]
  }
  ```
- **Per‑worktree config** (`.config/git_worktree_manager/config.json`):
  ```json
  {
    "buttons": [
      {
        "id": "rider",
        "label": "Rider",
        "icon": { "type": "appBundle", "bundleId": "com.jetbrains.rider" },
        "availability": { "bundleId": "com.jetbrains.rider" },
        "command": ["open", "-a", "Rider.app", "$WORKTREE/Subito/Subito.slnx"]
      }
    ]
  }
  ```

## Data Model & Services (Implemented)
- **Core services:**
  - `ProjectsConfigStore`, `WorktreeConfigLoader`, `GitClient`, `WorktreeActivityReader`
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
- Path: `~/gwm/<projectName>/<cityName>`.
- City names list is embedded in code (see `Sources/GWMApp/CityNames.swift`).
- Branch name = city name.

## Buttons & Commands (Implemented)
- **Defaults:** Ghostty + Fork.
- **Config buttons:** merged after defaults.
- **Templating:** simple `$VAR` replacement.
- **Availability:** bundle-id check; missing apps are disabled + gray.

## Ghostty Window Focus (Implemented)
- AX lookup of window title `GWM: <WorktreeName>`.
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

## Smoke Check / Verification
- Tests: `swift test`
- App startup (auto-quit): `GWM_AUTO_QUIT=1 swift run`

## Known Behavior
- Invalid or missing bare repo paths are skipped (and errors are printed).
- If Accessibility permissions are missing, Ghostty focus falls back to opening a new window.

