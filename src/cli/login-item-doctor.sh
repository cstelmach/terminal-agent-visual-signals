#!/bin/bash
# ==============================================================================
# TAVS CLI — login-item doctor (shared by install/uninstall macos-app)
# ==============================================================================
# Detects and cleans stale TAVSApp login items: raw SwiftPM .build executables
# that self-registered before the LoginItemRegistrationPolicy gate (127e648).
#
# SMAppService can only inspect the CURRENT bundle's registration, so
# enumeration goes through System Events, the same path documented in
# docs/reference/macos-menubar-app.md ("Terminal opens `TAVSApp ; exit;`").
# Everything here is best-effort: on any failure we fall back to printing
# manual System Settings guidance instead of erroring the install/uninstall.
# ==============================================================================

# Prints one "name|path" line per TAVS/TAVSApp login item. Returns non-zero
# when System Events is unavailable or Automation permission is denied.
_tavs_login_item_scan() {
    osascript 2>/dev/null <<'APPLESCRIPT'
tell application "System Events"
    set out to ""
    repeat with li in (every login item whose name is "TAVSApp" or name is "TAVS")
        set out to out & (name of li) & "|" & (path of li) & linefeed
    end repeat
    return out
end tell
APPLESCRIPT
}

# Reports all TAVS login items. Auto-removes ONLY stale debug entries
# (path contains ".build/"). Unexpected entries are surfaced, never deleted.
_tavs_login_item_doctor() {
    local scan
    if ! scan=$(_tavs_login_item_scan); then
        cli_info "Could not inspect login items (System Events unavailable or not authorized)."
        cli_info "Check manually: System Settings → General → Login Items."
        return 0
    fi

    local name path stale_found=false healthy_found=false
    while IFS='|' read -r name path; do
        [[ -z "$name" ]] && continue

        if [[ "$path" == "/Applications/TAVS.app"* ]]; then
            healthy_found=true
            echo "  Login item OK: $path"
            continue
        fi

        if [[ "$path" == *".build/"* ]]; then
            stale_found=true
            cli_info "Stale debug login item: $path"
            _tavs_remove_stale_login_item "$name" "$path"
            continue
        fi

        # Unknown TAVS entry: report only. Auto-deleting here could remove a
        # legitimate item we do not recognize (e.g. HFS-style path rendering).
        cli_info "Unexpected TAVS login item (not touched): $path"
        cli_info "Review in System Settings → General → Login Items if unwanted."
    done <<< "$scan"

    if [[ "$stale_found" == "false" ]]; then
        echo "  No stale TAVS login items found"
    fi
    [[ "$healthy_found" == "true" ]] && return 0
    return 0
}

# Removal strategy for one stale entry: prefer SMAppService self-unregistration
# (the registration is keyed to that executable), fall back to System Events
# deletion, finally print manual guidance.
_tavs_remove_stale_login_item() {
    local name="$1" path="$2"

    if [[ -x "$path" ]]; then
        if "$path" --unregister-login-item &>/dev/null; then
            echo "  Unregistered via: $path --unregister-login-item"
            return 0
        fi
    fi

    if osascript -e "tell application \"System Events\" to delete (every login item whose path is \"$path\")" &>/dev/null; then
        echo "  Removed via System Events"
        return 0
    fi

    cli_info "Remove manually: System Settings → General → Login Items (entry: $name)"
    return 1
}
