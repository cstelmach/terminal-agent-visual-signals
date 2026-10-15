#!/usr/bin/env bats

setup() {
    [[ -n "${TAVS_TEST_ROOT:-}" && -x "${TAVS_TEST_HELPER_BIN:-}" ]] || return 1
    export TAVS_TEST_ROOT="$(cd "$TAVS_TEST_ROOT" && pwd -P)"
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    TEST_DIR=$(mktemp -d "$TAVS_TEST_ROOT/install-app.XXXXXX")
    TEST_DIR=$(cd "$TEST_DIR" && pwd)
    export HOME="$TEST_DIR/home" CFFIXED_USER_HOME="$TEST_DIR/home" ZDOTDIR="$TEST_DIR/home"
    export TAVS_RUNTIME_DIR="$TEST_DIR/runtime" TAVS_TMP_DIR="$TEST_DIR/state" _TAVS_TMP_DIR="$TEST_DIR/state"
    export XDG_RUNTIME_DIR="$TEST_DIR/xdg" XDG_CONFIG_HOME="$TEST_DIR/config"
    export APP_FIXTURE="$TEST_DIR" INSTALL_FAILURE='' INSTALL_EVENTS="$TEST_DIR/events"
    mkdir -p "$TEST_DIR/bin" "$TEST_DIR/apps/TAVS.app" "$TEST_DIR/build/TAVS.app/Contents/MacOS"
    printf 'prior bundle 43\n' > "$TEST_DIR/apps/TAVS.app/prior.txt"
    printf 'current bundle 43\n' > "$TEST_DIR/build/TAVS.app/current.txt"
    /bin/cp "$REPO_ROOT/src/macos/TAVSApp/Resources/Info.plist" "$TEST_DIR/build/TAVS.app/Contents/Info.plist"
    printf '#!/bin/bash\nexit 0\n' > "$TEST_DIR/build/TAVS.app/Contents/MacOS/TAVSApp"
    chmod +x "$TEST_DIR/build/TAVS.app/Contents/MacOS/TAVSApp"
    cat > "$TEST_DIR/bin/installer-command" <<'STUB'
#!/bin/bash
set -eu
[[ "$APP_FIXTURE" == "$TAVS_TEST_ROOT/"* ]] || exit 90
name=${0##*/}
printf '%s\n' "$name" >> "$INSTALL_EVENTS"
case "$name" in
    pgrep|killall|sleep|xattr) exit 0 ;;
    open) exit 91 ;;
    codesign)
        [[ "$4" == "$APP_FIXTURE/apps/.tavs-install."*/TAVS.app ]] || exit 94
        [[ "$INSTALL_FAILURE" != signature ]]; exit
        ;;
    cp)
        if [[ "$INSTALL_FAILURE" == copy ]]; then
            mkdir "$3"
            printf 'partial copy\n' > "$3/partial.txt"
            exit 1
        fi
        /bin/cp "$@" || exit 1
        if [[ "$INSTALL_FAILURE" == copied-plist ]]; then
            printf 'damaged during copy\n' > "$3/Contents/Info.plist"
        fi
        exit 0
        ;;
    mv)
        [[ "$1" == -n ]] && shift
        [[ "$1" == "$APP_FIXTURE/"* && "$2" == "$APP_FIXTURE/"* ]] || exit 92
        case "$1" in
            */previous/TAVS.app)
                [[ "$INSTALL_FAILURE" != restore ]] || exit 1
                ;;
            */.tavs-install.*/TAVS.app)
                case "$INSTALL_FAILURE" in
                    activation|restore) exit 1 ;;
                    conflict)
                        mkdir "$APP_FIXTURE/apps/TAVS.app"
                        printf 'unexpected destination\n' > "$APP_FIXTURE/apps/TAVS.app/conflict.txt"
                        ;;
                esac
                ;;
        esac
        exec /bin/mv -n "$@"
        ;;
    *) exit 93 ;;
esac
STUB
    chmod +x "$TEST_DIR/bin/installer-command"
    local command
    for command in pgrep killall sleep xattr open codesign cp mv; do
        ln -s installer-command "$TEST_DIR/bin/$command"
    done
    export PATH="$TEST_DIR/bin:$PATH"
}

install_fixture() {
    run /bin/bash -e -c '
[[ "$2" == "$TAVS_TEST_ROOT/"* ]] || exit 90
TAVS_ROOT="$1" CLI_DIR="$1/src/cli"
source "$CLI_DIR/cmd-install-macos-app.sh"
_TAVS_BUILD_DIR="$2/build" _TAVS_APP_DEST="$2/apps/TAVS.app" _DRY_RUN="${3:-false}"
if [[ "${4:-bundle}" == command ]]; then
    _check_prerequisites() { :; }
    _build_swift() { :; }
    _assemble_bundle() { :; }
    _generate_icon() { :; }
    _codesign_bundle() { :; }
    _launch_and_register() { printf "LAUNCH_REACHED\n"; }
    _tavs_login_item_doctor() { :; }
    if cmd_install_macos_app; then exit 0; else exit $?; fi
else
    _install_bundle
fi
' _ "$REPO_ROOT" "$TEST_DIR" "${1:-false}" "${2:-bundle}"
}

assert_prior_preserved() {
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_DIR/apps/TAVS.app/prior.txt")" = 'prior bundle 43' ]
    [ ! -e "$TEST_DIR/apps/TAVS.app/current.txt" ]
    [[ "$output" != *'Installed to '* ]]
}

assert_not_stopped() {
    [[ ! -e "$INSTALL_EVENTS" ]] || ! grep -Eq '^(pgrep|killall|open)$' "$INSTALL_EVENTS"
}

@test "partial copy failure preserves the prior app without stopping it" {
    export INSTALL_FAILURE=copy
    install_fixture
    assert_prior_preserved
    assert_not_stopped
}

@test "staged signature failure preserves the prior app without stopping it" {
    export INSTALL_FAILURE=signature
    install_fixture
    assert_prior_preserved
    assert_not_stopped
}

@test "validation rejects copy corruption and unexpected bundle identity" {
    export INSTALL_FAILURE=copied-plist
    install_fixture
    assert_prior_preserved
    assert_not_stopped
    export INSTALL_FAILURE=''
    /usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.example.other' "$TEST_DIR/build/TAVS.app/Contents/Info.plist"
    install_fixture
    assert_prior_preserved
    assert_not_stopped
}

@test "invalid copied plist or non-executable helper preserves the prior app" {
    printf 'invalid plist\n' > "$TEST_DIR/build/TAVS.app/Contents/Info.plist"
    install_fixture
    assert_prior_preserved
    assert_not_stopped
    /bin/cp "$REPO_ROOT/src/macos/TAVSApp/Resources/Info.plist" "$TEST_DIR/build/TAVS.app/Contents/Info.plist"
    chmod -x "$TEST_DIR/build/TAVS.app/Contents/MacOS/TAVSApp"
    install_fixture
    assert_prior_preserved
    assert_not_stopped
}

@test "replacement installs an unmixed bundle and retains the previous copy" {
    install_fixture
    [ "$status" -eq 0 ]
    [ "$(cat "$TEST_DIR/apps/TAVS.app/current.txt")" = 'current bundle 43' ]
    [ ! -e "$TEST_DIR/apps/TAVS.app/prior.txt" ]
    [ ! -e "$TEST_DIR/apps/TAVS.app/TAVS.app" ]
    local prior=("$TEST_DIR"/apps/.tavs-install.*/previous/TAVS.app/prior.txt)
    [ "${#prior[@]}" -eq 1 ]
    [ "$(cat "${prior[0]}")" = 'prior bundle 43' ]
    [[ "$output" == *"${prior[0]%/prior.txt}"* && "$output" == *'Installed to '* ]]
}

@test "activation failure restores the previous bundle and reports failure" {
    export INSTALL_FAILURE=activation
    install_fixture
    assert_prior_preserved
    [[ "$output" == *'restored'* ]]
}

@test "failed restoration retains and reports the previous bundle path" {
    export INSTALL_FAILURE=restore
    install_fixture
    [ "$status" -ne 0 ]
    local prior=("$TEST_DIR"/apps/.tavs-install.*/previous/TAVS.app/prior.txt)
    [ "$(cat "${prior[0]}")" = 'prior bundle 43' ]
    [[ "$output" == *"${prior[0]%/prior.txt}"* && "$output" != *'Installed to '* ]]
}

@test "a conflicting destination is preserved without nesting the prior bundle" {
    export INSTALL_FAILURE=conflict
    install_fixture
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_DIR/apps/TAVS.app/conflict.txt")" = 'unexpected destination' ]
    [ ! -e "$TEST_DIR/apps/TAVS.app/TAVS.app" ]
    local prior=("$TEST_DIR"/apps/.tavs-install.*/previous/TAVS.app/prior.txt)
    [ "$(cat "${prior[0]}")" = 'prior bundle 43' ]
    [[ "$output" == *"${prior[0]%/prior.txt}"* ]]
}

@test "linked and non-directory destinations are rejected before stopping" {
    /bin/mv "$TEST_DIR/apps/TAVS.app" "$TEST_DIR/original.app"
    ln -s "$TEST_DIR/original.app" "$TEST_DIR/apps/TAVS.app"
    install_fixture
    assert_prior_preserved
    assert_not_stopped
    /bin/mv "$TEST_DIR/apps/TAVS.app" "$TEST_DIR/prior-link"
    printf 'unrelated file\n' > "$TEST_DIR/apps/TAVS.app"
    install_fixture
    [ "$status" -ne 0 ]
    [ "$(cat "$TEST_DIR/apps/TAVS.app")" = 'unrelated file' ]
    assert_not_stopped
}

@test "first installation works and dry-run makes no staging or process changes" {
    /bin/mv "$TEST_DIR/apps/TAVS.app" "$TEST_DIR/original.app"
    install_fixture true
    [ "$status" -eq 0 ]
    [ ! -e "$INSTALL_EVENTS" ]
    [ "$(find "$TEST_DIR/apps" -mindepth 1 | wc -l | tr -d ' ')" = 0 ]
    install_fixture
    [ "$status" -eq 0 ]
    [ -x "$TEST_DIR/apps/TAVS.app/Contents/MacOS/TAVSApp" ]
    [ "$(cat "$TEST_DIR/apps/TAVS.app/current.txt")" = 'current bundle 43' ]
}

@test "full command propagates replacement failure even when errexit is suppressed" {
    export INSTALL_FAILURE=copy
    install_fixture false command
    assert_prior_preserved
    assert_not_stopped
    [[ "$output" != *LAUNCH_REACHED* && "$output" != *'installed successfully'* ]]
}
