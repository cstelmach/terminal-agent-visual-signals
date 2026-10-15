#!/bin/bash
# ==============================================================================
# TAVS CLI — install macos-app
# ==============================================================================
# Usage: tavs install macos-app [--dry-run] [--help]
#
# Builds, bundles, codesigns, and installs TAVS.app to /Applications.
# The app self-registers as a login item via SMAppService on launch; this
# script only launches it and verifies the registration took effect.
# ==============================================================================

source "$CLI_DIR/cli-utils.sh"
source "$CLI_DIR/login-item-doctor.sh"

_TAVS_APP_VERSION="${TAVS_VERSION:-3.0.0}"
_TAVS_BUILD_DIR="/tmp/TAVS-build"
_TAVS_APP_DEST="/Applications/TAVS.app"
_TAVS_CERT_NAME="TAVS-Local-Signing"
_TAVS_BUNDLE_ID="com.cstelmach.tavs"
_TAVS_SWIFT_PKG="$TAVS_ROOT/src/macos/TAVSApp"
_TAVS_INFO_PLIST="$TAVS_ROOT/src/macos/TAVSApp/Resources/Info.plist"
_DRY_RUN=false

cmd_install_macos_app() {
    if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
        cat <<'EOF'
tavs install macos-app — Build and install the TAVS menu bar companion

Usage:
  tavs install macos-app              Build, sign, install, and register
  tavs install macos-app --dry-run    Show what would be done without executing

Steps performed:
  1. swift build -c release
  2. Assemble .app bundle in /tmp/TAVS-build/
  3. Create/reuse self-signed certificate (TAVS-Local-Signing)
  4. Codesign the bundle (ad-hoc fallback if cert fails)
  5. Stage and validate the replacement; preserve the prior app
  6. Launch and register as login item

Requirements:
  - macOS 13+ (Ventura or later)
  - Swift 5.9+ / Xcode 15+ command-line tools
  - Keychain access for certificate creation (one-time)
EOF
        return 0
    fi

    if [[ "${1:-}" == "--dry-run" ]]; then
        _DRY_RUN=true
        cli_info "[DRY RUN] Showing what would be done"
        echo ""
    fi

    _check_prerequisites
    _build_swift
    _assemble_bundle
    _generate_icon
    _codesign_bundle
    _install_bundle || return 1
    _launch_and_register

    if [[ "$_DRY_RUN" != "true" ]]; then
        cli_bold "Checking login items..."
        _tavs_login_item_doctor
    fi

    echo ""
    cli_success "TAVS.app installed successfully!"
    if [[ "$_DRY_RUN" == "true" ]]; then
        cli_info "[DRY RUN] No changes were made to the system."
    else
        cli_info "Menu bar icon should appear momentarily."
        cli_info "To uninstall: tavs uninstall macos-app"
    fi
}

_check_prerequisites() {
    cli_bold "Checking prerequisites..."

    local sw_ver
    sw_ver=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
    local major="${sw_ver%%.*}"
    if [[ "$major" -lt 13 ]]; then
        cli_error "macOS 13+ required (found $sw_ver)"
        exit 1
    fi
    echo "  macOS $sw_ver — OK"

    if ! command -v swift &>/dev/null; then
        cli_error "Swift not found. Install Xcode command-line tools: xcode-select --install"
        exit 1
    fi
    echo "  Swift $(swift --version 2>&1 | head -1 | sed 's/.*version //' | cut -d' ' -f1) — OK"

    if ! command -v codesign &>/dev/null; then
        cli_error "codesign not found. Install Xcode command-line tools."
        exit 1
    fi
    echo "  codesign — OK"

    if [[ ! -f "$_TAVS_INFO_PLIST" ]]; then
        cli_error "Info.plist not found at $_TAVS_INFO_PLIST"
        exit 1
    fi
    echo "  Info.plist — OK"
    echo ""
}

_build_swift() {
    cli_bold "Building TAVSApp (release)..."
    if [[ "$_DRY_RUN" == "true" ]]; then
        echo "  Would run: swift build -c release --package-path $_TAVS_SWIFT_PKG"
        echo ""
        return
    fi

    if ! swift build -c release --package-path "$_TAVS_SWIFT_PKG" 2>&1; then
        cli_error "Swift build failed"
        exit 1
    fi
    echo ""
}

_assemble_bundle() {
    cli_bold "Assembling app bundle..."

    local bundle_dir="$_TAVS_BUILD_DIR/TAVS.app/Contents"

    if [[ "$_DRY_RUN" == "true" ]]; then
        echo "  Would create: $bundle_dir/MacOS/"
        echo "  Would create: $bundle_dir/Resources/"
        echo "  Would copy:   binary → $bundle_dir/MacOS/TAVSApp"
        echo "  Would copy:   Info.plist → $bundle_dir/"
        echo ""
        return
    fi

    rm -rf "$_TAVS_BUILD_DIR"
    mkdir -p "$bundle_dir/MacOS"
    mkdir -p "$bundle_dir/Resources"

    local binary
    binary=$(find "$_TAVS_SWIFT_PKG/.build/release" -name TAVSApp -type f -maxdepth 1 2>/dev/null | head -1)
    if [[ -z "$binary" ]]; then
        binary=$(find "$_TAVS_SWIFT_PKG/.build" -path "*/release/TAVSApp" -type f 2>/dev/null | head -1)
    fi
    if [[ -z "$binary" ]]; then
        cli_error "Built binary not found in $_TAVS_SWIFT_PKG/.build/"
        exit 1
    fi

    cp "$binary" "$bundle_dir/MacOS/TAVSApp"
    chmod +x "$bundle_dir/MacOS/TAVSApp"
    cp "$_TAVS_INFO_PLIST" "$bundle_dir/Info.plist"

    if ! plutil -lint "$bundle_dir/Info.plist" &>/dev/null; then
        cli_error "Info.plist validation failed"
        exit 1
    fi

    echo "  Bundle assembled at $_TAVS_BUILD_DIR/TAVS.app"
    echo ""
}

_generate_icon() {
    cli_bold "Generating app icon..."

    local iconset_dir="$_TAVS_BUILD_DIR/AppIcon.iconset"
    local icns_path="$_TAVS_BUILD_DIR/TAVS.app/Contents/Resources/AppIcon.icns"

    if [[ "$_DRY_RUN" == "true" ]]; then
        echo "  Would generate SF Symbol icon via sips"
        echo "  Would produce: $icns_path"
        echo ""
        return
    fi

    mkdir -p "$iconset_dir"

    local src_icns="$TAVS_ROOT/src/macos/TAVSApp/Resources/AppIcon.icns"
    if [[ -f "$src_icns" ]]; then
        cp "$src_icns" "$icns_path"
        echo "  Using pre-built icon"
        echo ""
        return
    fi

    _generate_icon_from_symbol "$iconset_dir" "$icns_path"
    echo ""
}

_generate_icon_from_symbol() {
    local iconset_dir="$1"
    local icns_path="$2"

    local sizes=(16 32 64 128 256 512)
    local tmp_svg="$_TAVS_BUILD_DIR/icon_base.png"

    # Generate a base 1024px icon using a simple colored circle with "T"
    # We can't use SF Symbols from bash, so create a minimal icon via sips
    local base_size=1024
    local base_png="$_TAVS_BUILD_DIR/base_icon.png"

    # Create a solid teal circle as base icon via a tiny Swift script
    local icon_swift="$_TAVS_BUILD_DIR/gen_icon.swift"
    cat > "$icon_swift" << 'SWIFT'
import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let path = NSBezierPath(ovalIn: rect.insetBy(dx: 40, dy: 40))

NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.65, alpha: 1.0).setFill()
path.fill()

let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.boldSystemFont(ofSize: 520),
    .foregroundColor: NSColor.white
]
let str = NSAttributedString(string: "T", attributes: attrs)
let strSize = str.size()
let strOrigin = NSPoint(
    x: (size.width - strSize.width) / 2,
    y: (size.height - strSize.height) / 2
)
str.draw(at: strOrigin)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fputs("Failed to create icon\n", stderr)
    exit(1)
}

let outputPath = CommandLine.arguments[1]
try! png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

    if ! swift "$icon_swift" "$base_png" 2>/dev/null; then
        echo "  Icon generation failed — using placeholder"
        touch "$icns_path"
        return
    fi

    for s in "${sizes[@]}"; do
        sips -z "$s" "$s" "$base_png" --out "$iconset_dir/icon_${s}x${s}.png" &>/dev/null
        local s2=$((s * 2))
        if [[ $s2 -le 1024 ]]; then
            sips -z "$s2" "$s2" "$base_png" --out "$iconset_dir/icon_${s}x${s}@2x.png" &>/dev/null
        fi
    done

    if command -v iconutil &>/dev/null; then
        iconutil -c icns "$iconset_dir" -o "$icns_path" 2>/dev/null || true
    fi

    if [[ -f "$icns_path" && -s "$icns_path" ]]; then
        echo "  Generated icon at $icns_path"
    else
        echo "  Icon generation incomplete — app will use default macOS icon"
    fi
}

_codesign_bundle() {
    cli_bold "Codesigning..."

    local app_path="$_TAVS_BUILD_DIR/TAVS.app"

    if [[ "$_DRY_RUN" == "true" ]]; then
        echo "  Would check/create certificate: $_TAVS_CERT_NAME"
        echo "  Would run: codesign --force --deep --sign $_TAVS_CERT_NAME $app_path"
        echo "  Fallback: codesign --force --deep --sign - $app_path (ad-hoc)"
        echo ""
        return
    fi

    if _cert_exists; then
        echo "  Certificate '$_TAVS_CERT_NAME' found"
    else
        echo "  Creating self-signed certificate '$_TAVS_CERT_NAME'..."
        echo "  (You may be prompted for Keychain access)"
        if ! _create_cert; then
            cli_info "Certificate creation failed — falling back to ad-hoc signing"
            cli_info "Note: Login item registration may not persist across reinstalls"
            _adhoc_sign "$app_path"
            return
        fi
        echo "  Certificate created"
    fi

    if codesign --force --deep --sign "$_TAVS_CERT_NAME" "$app_path" 2>/dev/null; then
        echo "  Signed with $_TAVS_CERT_NAME"
    else
        cli_info "Named signing failed — falling back to ad-hoc"
        _adhoc_sign "$app_path"
        return
    fi

    if ! codesign -vv "$app_path" &>/dev/null; then
        cli_error "Codesign verification failed"
        exit 1
    fi
    echo "  Signature verified"
    echo ""
}

_cert_exists() {
    security find-identity -v -p codesigning login.keychain-db 2>/dev/null \
        | grep -q "$_TAVS_CERT_NAME"
}

_create_cert() {
    # Clean up the temp keychain a pre-fix version of this script created and
    # never used (the cert lives in login.keychain-db; nothing references it).
    security delete-keychain /tmp/tavs-build.keychain-db 2>/dev/null || true

    local cert_pem="$_TAVS_BUILD_DIR/cert.pem"
    local key_pem="$_TAVS_BUILD_DIR/key.pem"
    local p12_path="$_TAVS_BUILD_DIR/cert.p12"

    openssl req -x509 -newkey rsa:2048 -keyout "$key_pem" -out "$cert_pem" \
        -days 3650 -nodes -subj "/CN=$_TAVS_CERT_NAME" 2>/dev/null || return 1

    openssl pkcs12 -export -out "$p12_path" -inkey "$key_pem" -in "$cert_pem" \
        -passout pass: 2>/dev/null || return 1

    security import "$p12_path" -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign -P "" 2>/dev/null || return 1

    security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" \
        ~/Library/Keychains/login.keychain-db 2>/dev/null || true

    rm -f "$cert_pem" "$key_pem" "$p12_path"
    return 0
}

_adhoc_sign() {
    local app_path="$1"
    codesign --force --deep --sign - "$app_path" 2>/dev/null
    if codesign -vv "$app_path" &>/dev/null; then
        echo "  Ad-hoc signed and verified"
    else
        cli_error "Ad-hoc signing also failed"
        exit 1
    fi
    echo ""
}

_install_bundle() {
    cli_bold "Installing to $_TAVS_APP_DEST..."

    if [[ "$_DRY_RUN" == "true" ]]; then
        echo "  Would stage and validate: $_TAVS_BUILD_DIR/TAVS.app beside $_TAVS_APP_DEST"
        echo "  Would then stop TAVSApp, preserve the prior app, and activate the replacement"
        echo ""
        return
    fi

    if [[ -L "$_TAVS_APP_DEST" || ( -e "$_TAVS_APP_DEST" && ! -d "$_TAVS_APP_DEST" ) ]]; then
        cli_error "Refusing unexpected app destination: $_TAVS_APP_DEST"
        return 1
    fi

    local parent="${_TAVS_APP_DEST%/*}" name="${_TAVS_APP_DEST##*/}" stage staged previous=''
    stage=$(mktemp -d "$parent/.tavs-install.XXXXXX") || {
        cli_error "Cannot stage replacement beside $_TAVS_APP_DEST"
        return 1
    }
    staged="$stage/$name"
    echo "  Staging replacement in $stage"
    if ! cp -R "$_TAVS_BUILD_DIR/TAVS.app" "$staged"; then
        cli_error "Replacement copy failed; prior app preserved. Staging retained at $stage"
        return 1
    fi
    if [[ ! -d "$staged" || ! -f "$staged/Contents/MacOS/TAVSApp" ||
          ! -x "$staged/Contents/MacOS/TAVSApp" ]] ||
        ! plutil -lint "$staged/Contents/Info.plist" >/dev/null 2>&1 ||
        [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$staged/Contents/Info.plist" 2>/dev/null)" != "$_TAVS_BUNDLE_ID" ||
           "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$staged/Contents/Info.plist" 2>/dev/null)" != TAVSApp ]] ||
        ! codesign --verify --deep --strict "$staged" >/dev/null 2>&1; then
        cli_error "Staged app validation failed; prior app preserved. Staging retained at $stage"
        return 1
    fi
    mkdir "$stage/previous" || return 1

    if pgrep -x TAVSApp &>/dev/null; then
        echo "  Stopping existing TAVS.app..."
        killall TAVSApp 2>/dev/null || true
        sleep 1
    fi

    # Same-volume moves preserve the prior bundle without merging app resources.
    if [[ -L "$_TAVS_APP_DEST" || ( -e "$_TAVS_APP_DEST" && ! -d "$_TAVS_APP_DEST" ) ]]; then
        cli_error "App destination changed; refusing replacement. Staging retained at $stage"
        return 1
    fi
    if [[ -d "$_TAVS_APP_DEST" ]]; then
        previous="$stage/previous/$name"
        if ! mv -n "$_TAVS_APP_DEST" "$stage/previous/" ||
            [[ -e "$_TAVS_APP_DEST" || -L "$_TAVS_APP_DEST" || ! -d "$previous" ]]; then
            cli_error "Cannot preserve prior app; inspect $_TAVS_APP_DEST and $stage"
            return 1
        fi
        echo "  Previous app retained at $previous"
    fi

    # mv -n can skip an occupied destination and return success; check the source too.
    if ! mv -n "$staged" "$parent/" || [[ -e "$staged" || -L "$staged" ]]; then
        if [[ -n "$previous" ]]; then
            if [[ ! -e "$_TAVS_APP_DEST" && ! -L "$_TAVS_APP_DEST" ]] &&
                mv -n "$previous" "$parent/" && [[ ! -e "$previous" && ! -L "$previous" ]]; then
                cli_error "Replacement activation failed; previous app restored to $_TAVS_APP_DEST"
            else
                cli_error "Replacement activation failed; previous app retained at $previous"
                cli_error "Inspect $_TAVS_APP_DEST before restoring it; destination was not overwritten"
            fi
        else
            cli_error "Replacement activation failed; staging retained at $stage"
        fi
        return 1
    fi

    echo "  Installed to $_TAVS_APP_DEST"

    # Remove quarantine if present
    xattr -dr com.apple.quarantine "$_TAVS_APP_DEST" 2>/dev/null || true
    echo ""
}

_launch_and_register() {
    cli_bold "Launching and registering login item..."

    if [[ "$_DRY_RUN" == "true" ]]; then
        echo "  Would run: open $_TAVS_APP_DEST"
        echo "  Would verify login item status via --reported-status"
        echo ""
        return
    fi

    open "$_TAVS_APP_DEST"
    sleep 2

    if pgrep -x TAVSApp &>/dev/null; then
        echo "  TAVS.app is running"
    else
        cli_info "App may still be launching..."
    fi

    # The app's AppDelegate calls SMAppService.register() on launch. Poll a few
    # times because registration is asynchronous: a fresh-bundle first launch
    # can take a moment to settle.
    local status_output
    local attempts=0
    while (( attempts < 5 )); do
        status_output=$("$_TAVS_APP_DEST/Contents/MacOS/TAVSApp" --reported-status 2>/dev/null) || true
        if echo "$status_output" | grep -q "login_item_status=enabled"; then
            echo "  Login item: enabled (survives reboots)"
            echo ""
            return 0
        fi
        attempts=$((attempts + 1))
        sleep 1
    done

    # Reached only when SMAppService never transitioned to .enabled. The app
    # is still installed and usable for this session; the user just needs to
    # finish login-item approval via System Settings. Loud and actionable.
    echo ""
    cli_info "Login item NOT registered. TAVS will not start automatically at login."
    cli_info "To fix: System Settings → General → Login Items → enable 'TAVS'."
    cli_info "If 'TAVS' is missing from the list, the bundle's code signature may be"
    cli_info "incompatible with SMAppService — re-run with TAVS_SIGNING_IDENTITY set."
    echo ""
}
