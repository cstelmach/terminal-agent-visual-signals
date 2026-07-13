#!/usr/bin/env bats
# ==============================================================================
# Unit tests for src/core/challenge.sh + unlock/set-password in cmd-lock.sh
# ==============================================================================
# Answers are piped via stdin (the prompts read stdin, not /dev/tty).
# ==============================================================================

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d)
    TEST_HOME="$TEST_DIR/home"
    TEST_RUNTIME="$TEST_DIR/runtime"
    mkdir -p "$TEST_HOME/.tavs" "$TEST_RUNTIME"

    export HOME="$TEST_HOME"
    export TAVS_RUNTIME_DIR="$TEST_RUNTIME"
    export CLI_DIR="$REPO_ROOT/src/cli"
    export TAVS_ROOT="$REPO_ROOT"

    source "$REPO_ROOT/src/core/challenge.sh"
    NOW=$(date +%s)
}

teardown() {
    rm -rf "$TEST_DIR"
}

write_password_conf() {
    # password "hunter2" with a fixed salt
    local salt="00112233445566778899aabbccddeeff"
    local hash
    hash=$(printf '%s%s' "$salt" "hunter2" | shasum -a 256 | cut -d' ' -f1)
    cat > "$TEST_HOME/.tavs/challenge.conf" <<EOF
CHALLENGE_TYPE="password"
PASSWORD_SALT_HEX="$salt"
PASSWORD_HASH_HEX="$hash"
PUZZLE_SENTENCES_FILE=""
SCHEMA_VERSION="1"
EOF
}

write_single_sentence_pool() {
    # Deterministic puzzle: one sentence only.
    echo "the quick brown fox" > "$TEST_DIR/pool.txt"
    cat > "$TEST_HOME/.tavs/challenge.conf" <<EOF
CHALLENGE_TYPE="puzzle"
PUZZLE_SENTENCES_FILE="$TEST_DIR/pool.txt"
SCHEMA_VERSION="1"
EOF
}

# --- Hash + transform vectors (must match ChallengeVerifierTests.swift) ---

@test "hash spec: salt-hex string concatenated with password" {
    local got
    got=$(_tavs_challenge_hash "aabb" "secret")
    local want
    want=$(printf 'aabbsecret' | shasum -a 256 | cut -d' ' -f1)
    [ "$got" = "$want" ]
}

@test "transform: first letter of each word moves to its end" {
    [ "$(_tavs_puzzle_transform 'the quick brown fox')" = "het uickq rownb oxf" ]
}

@test "transform: single-letter words map to themselves" {
    [ "$(_tavs_puzzle_transform 'a calm mind')" = "a almc indm" ]
}

# --- Verify: password ---

@test "password challenge: correct password passes" {
    write_password_conf
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "hunter2\n" | _tavs_challenge_verify'
    [ "$status" -eq 0 ]
}

@test "password challenge: three wrong attempts fail" {
    write_password_conf
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "a\nb\nc\n" | _tavs_challenge_verify'
    [ "$status" -ne 0 ]
    [[ "$output" == *"Wrong (3/3)"* ]]
}

@test "password challenge: succeeds on second attempt" {
    write_password_conf
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "nope\nhunter2\n" | _tavs_challenge_verify'
    [ "$status" -eq 0 ]
}

# --- Verify: puzzle ---

@test "puzzle challenge: correct transform passes" {
    write_single_sentence_pool
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "het uickq rownb oxf\n" | _tavs_challenge_verify'
    [ "$status" -eq 0 ]
}

@test "puzzle challenge: typing the ORIGINAL sentence fails" {
    write_single_sentence_pool
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "the quick brown fox\nthe quick brown fox\nthe quick brown fox\n" | _tavs_challenge_verify'
    [ "$status" -ne 0 ]
}

@test "no challenge.conf falls back to the puzzle" {
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; _tavs_challenge_load_config; echo "$_CH_TYPE"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"puzzle"* ]]
}

@test "password type without a stored hash degrades to puzzle" {
    printf 'CHALLENGE_TYPE="password"\nSCHEMA_VERSION="1"\n' > "$TEST_HOME/.tavs/challenge.conf"
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; _tavs_challenge_load_config; echo "$_CH_TYPE"'
    [[ "$output" == *"puzzle"* ]]
}

@test "both: password then puzzle, both required" {
    write_single_sentence_pool
    local salt="00112233445566778899aabbccddeeff"
    local hash
    hash=$(printf '%s%s' "$salt" "pw" | shasum -a 256 | cut -d' ' -f1)
    cat > "$TEST_HOME/.tavs/challenge.conf" <<EOF
CHALLENGE_TYPE="both"
PASSWORD_SALT_HEX="$salt"
PASSWORD_HASH_HEX="$hash"
PUZZLE_SENTENCES_FILE="$TEST_DIR/pool.txt"
SCHEMA_VERSION="1"
EOF
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "pw\nhet uickq rownb oxf\n" | _tavs_challenge_verify'
    [ "$status" -eq 0 ]
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "pw\nwrong\nwrong\nwrong\n" | _tavs_challenge_verify'
    [ "$status" -ne 0 ]
}

# --- tavs unlock / set-password (through cmd-lock.sh) ---

@test "unlock: no effective lock is a clean no-op" {
    source "$CLI_DIR/cmd-lock.sh"
    run cmd_lock unlock --for 1h
    [ "$status" -eq 0 ]
    [[ "$output" == *"No effective lock"* ]]
}

@test "unlock: correct challenge writes a grant, lock re-engages later" {
    write_single_sentence_pool
    source "$CLI_DIR/cmd-lock.sh"
    _tavs_lock_write "true" "manual" "$(( NOW + 7200 ))" "0" "#111111" ""
    run bash -c "cd '$REPO_ROOT' && printf 'het uickq rownb oxf\n' | ./tavs unlock --for 15m"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Unlocked until"* ]]
    local grant
    grant=$(grep '^UNLOCK_UNTIL_EPOCH=' "$TEST_RUNTIME/lock.state" | cut -d'"' -f2)
    (( grant >= NOW + 890 && grant <= NOW + 910 ))
    # Lock itself untouched.
    grep -q 'LOCKED="true"' "$TEST_RUNTIME/lock.state"
    # After the grant expires the predicate re-locks.
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    ! _tavs_lock_effective "$NOW"
    _tavs_lock_effective "$(( NOW + 1000 ))"
}

@test "unlock: failed challenge leaves the lock untouched" {
    write_single_sentence_pool
    source "$CLI_DIR/cmd-lock.sh"
    _tavs_lock_write "true" "manual" "$(( NOW + 7200 ))" "0" "#111111" ""
    run bash -c "cd '$REPO_ROOT' && printf 'x\nx\nx\n' | ./tavs unlock --for 15m"
    [ "$status" -ne 0 ]
    grep -q 'UNLOCK_UNTIL_EPOCH="0"' "$TEST_RUNTIME/lock.state"
}

@test "set-password writes 600-mode conf and password then verifies" {
    source "$CLI_DIR/cmd-lock.sh"
    run bash -c "cd '$REPO_ROOT' && printf 'mypw\nmypw\n' | ./tavs lock set-password"
    [ "$status" -eq 0 ]
    [ -f "$TEST_HOME/.tavs/challenge.conf" ]
    local perms
    perms=$(stat -f '%Lp' "$TEST_HOME/.tavs/challenge.conf")
    [ "$perms" = "600" ]
    grep -q 'CHALLENGE_TYPE="password"' "$TEST_HOME/.tavs/challenge.conf"
    run bash -c 'source "'"$REPO_ROOT"'/src/core/challenge.sh"; printf "mypw\n" | _tavs_challenge_verify'
    [ "$status" -eq 0 ]
}

@test "set-password rejects mismatched passwords" {
    source "$CLI_DIR/cmd-lock.sh"
    run bash -c "cd '$REPO_ROOT' && printf 'one\ntwo\n' | ./tavs lock set-password"
    [ "$status" -ne 0 ]
    [ ! -f "$TEST_HOME/.tavs/challenge.conf" ]
}

# --- Schedule gating (spec D7) ---

@test "schedule resume is challenge-gated while hard-locked" {
    write_single_sentence_pool
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    _tavs_lock_write "true" "manual" "$(( NOW + 7200 ))" "0" "" ""
    run bash -c "cd '$REPO_ROOT' && printf 'x\nx\nx\n' | ./tavs schedule resume"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requires the unlock challenge"* ]]
    run bash -c "cd '$REPO_ROOT' && printf 'het uickq rownb oxf\n' | ./tavs schedule resume"
    [ "$status" -eq 0 ]
}

@test "schedule pause is never gated" {
    source "$TAVS_ROOT/src/core/lock-state-lib.sh"
    _tavs_lock_write "true" "manual" "$(( NOW + 7200 ))" "0" "" ""
    run bash -c "cd '$REPO_ROOT' && ./tavs schedule pause </dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" != *"challenge"* ]]
}

@test "schedule resume is ungated without a lock" {
    run bash -c "cd '$REPO_ROOT' && ./tavs schedule resume </dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" != *"challenge"* ]]
}
