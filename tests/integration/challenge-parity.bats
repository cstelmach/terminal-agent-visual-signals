#!/usr/bin/env bats
# ==============================================================================
# Contract test: shell and Swift password hashing must agree byte-for-byte.
# Spec 2.4: hash = lowercase-hex SHA256(UTF8(salt_hex_string + password)).
# Modeled on schedule-evaluator-parity.bats (dual implementation, one spec).
# ==============================================================================

setup_file() {
    export REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export SWIFT_PKG="$REPO_ROOT/src/macos/TAVSApp"

    if ! command -v swift &>/dev/null; then
        skip "swift not available"
    fi

    swift build -c release --package-path "$SWIFT_PKG" 2>/dev/null
    export SWIFT_BIN="$SWIFT_PKG/.build/release/TAVSApp"
}

_shell_hash() {
    source "$REPO_ROOT/src/core/challenge.sh"
    _tavs_challenge_hash "$1" "$2"
}

_assert_parity() {
    local salt="$1" password="$2"
    local shell_hash swift_hash
    shell_hash=$(_shell_hash "$salt" "$password")
    swift_hash=$("$SWIFT_BIN" --verify-password-hash "$salt" "$password")
    echo "salt=$salt pw=$password shell=$shell_hash swift=$swift_hash"
    [ -n "$shell_hash" ]
    [ "$shell_hash" = "$swift_hash" ]
}

@test "parity: simple ascii password" {
    _assert_parity "00112233445566778899aabbccddeeff" "hunter2"
}

@test "parity: empty password" {
    _assert_parity "00112233445566778899aabbccddeeff" ""
}

@test "parity: unicode password (umlauts + emoji)" {
    _assert_parity "aabbccddeeff00112233445566778899" "pässwörd🔒"
}

@test "parity: whitespace and shell-special characters" {
    _assert_parity "deadbeefdeadbeefdeadbeefdeadbeef" 'sp ace$"quote\back'
}

@test "parity: long password" {
    _assert_parity "0123456789abcdef0123456789abcdef" "$(printf 'x%.0s' {1..200})"
}

@test "parity: salt is concatenated as literal hex STRING (uppercase differs)" {
    # Guards the spec detail: the salt hex string itself is hashed, so the
    # same bytes written in uppercase must produce a DIFFERENT digest.
    local lower upper
    lower=$(_shell_hash "aabb" "pw")
    upper=$(_shell_hash "AABB" "pw")
    [ "$lower" != "$upper" ]
    local swift_lower
    swift_lower=$("$SWIFT_BIN" --verify-password-hash "aabb" "pw")
    [ "$lower" = "$swift_lower" ]
}
