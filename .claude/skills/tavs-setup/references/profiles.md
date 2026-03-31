# TAVS Profile Management

How to save, list, apply, and delete named configuration profiles.

## 1. What is a Profile

A profile is a selective set of key-value pairs representing a named TAVS
configuration. It's **not** a full `user.conf` snapshot — just the settings the
user explicitly wants in the profile.

Profiles let users quickly switch between configurations for different contexts
(e.g., a "presentation" profile with rich visuals vs. a "minimal" profile with
just colors).

## 2. Storage & Format

- **Location:** `~/.tavs/profiles/<name>.conf`
- **Format:** One shell variable assignment per line (same format as `user.conf`)
- **Profile names:** Lowercase alphanumeric + hyphens, no spaces
- **Encoding:** UTF-8 (faces contain Unicode)

Example file `~/.tavs/profiles/minimal.conf`:
```bash
THEME_PRESET="nord"
THEME_MODE="preset"
TAVS_TITLE_MODE="off"
ENABLE_ANTHROPOMORPHISING="false"
```

## 3. Save Profile

1. Ask the user for a descriptive profile name (validate: lowercase, alphanumeric,
   hyphens only)
2. Ask which settings to capture:
   - **Specific settings** — "save theme and face-mode" -> extract just those
   - **All active** — extract all uncommented, non-default settings from `user.conf`
3. Create directory if needed: `mkdir -p ~/.tavs/profiles`
4. Write selected settings to `~/.tavs/profiles/<name>.conf`
5. Confirm: "Saved profile `<name>` with N settings"

**Extracting active settings** from `user.conf`:
- Read each non-comment, non-empty line
- Skip section headers (lines starting with `#`)
- Include lines matching `VARIABLE="value"` or `VARIABLE=(array)` pattern

## 4. List Profiles

1. List all `.conf` files in `~/.tavs/profiles/`
2. For each profile, show:
   - Profile name (filename without `.conf`)
   - Number of settings
   - First 3-5 setting names as summary

Example output:
```
Available profiles:
  minimal       (3 settings: THEME_PRESET, TAVS_TITLE_MODE, ENABLE_ANTHROPOMORPHISING)
  presentation  (6 settings: THEME_PRESET, TAVS_TITLE_MODE, TAVS_FACE_MODE, ...)
  coding        (4 settings: THEME_PRESET, TAVS_TITLE_MODE, TAVS_FACE_MODE, ...)
```

If `~/.tavs/profiles/` doesn't exist or is empty, inform the user: "No profiles
saved yet."

## 5. Apply Profile

1. Read the profile file (`~/.tavs/profiles/<name>.conf`)
2. **Back up** current `user.conf` (same protocol as `config-workflow.md` Section 2)
3. **Preview** each setting from the profile alongside current values:
   > | Setting | Current | From Profile |
   > |---------|---------|--------------|
   > | `THEME_PRESET` | `dracula` | `nord` |
   > | `TAVS_TITLE_MODE` | `full` | `off` |
4. **Confirm** via AskUserQuestion: Apply / Edit / Cancel
5. **Apply** each setting:
   - Check if setting name matches a CLI alias -> use `./tavs set <alias> <value>`
   - Otherwise -> use Edit tool on `~/.tavs/user.conf`
6. **Verify** with `./tavs status`

**Important:** Applying a profile does NOT remove settings not in the profile.
It only overwrites the settings the profile specifies. For a clean slate, reset
to defaults first (`./tavs config reset`), then apply the profile.

## 6. Delete Profile

1. Confirm the profile exists in `~/.tavs/profiles/`
2. Ask confirmation via AskUserQuestion: "Delete profile `<name>`?"
3. Remove the file: `rm ~/.tavs/profiles/<name>.conf`
4. Confirm: "Deleted profile `<name>`"

## 7. Example Profiles

Three ready-made configurations users might want to create:

**minimal** — Bare minimum visual signals:
```bash
THEME_PRESET="nord"
THEME_MODE="preset"
TAVS_TITLE_MODE="off"
ENABLE_ANTHROPOMORPHISING="false"
```

**presentation** — Rich visuals for demos:
```bash
THEME_PRESET="nord"
THEME_MODE="preset"
TAVS_TITLE_MODE="full"
TAVS_FACE_MODE="compact"
TAVS_COMPACT_THEME="squares"
ENABLE_SESSION_ICONS="true"
```

**coding** — Clean coding setup:
```bash
THEME_PRESET="dracula"
THEME_MODE="preset"
TAVS_TITLE_MODE="skip-processing"
TAVS_FACE_MODE="standard"
```

These are examples — users can create profiles with any combination of settings.
