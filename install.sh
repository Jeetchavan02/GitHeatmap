#!/bin/bash
# GitHeatmap installer: downloads the latest release DMG, verifies it, and
# installs GitHeatmap.app into /Applications. Nothing is installed unless every
# check passes.
#
# Usage:
#   install.sh                 Verify and install the latest release
#   install.sh --verify-only   Run all checks, change nothing
#   install.sh --dmg <path>    Check a local DMG against the latest release digest
#
# Wrapped in main() so a partial download through `curl | bash` cannot run
# half a script.

set -euo pipefail

main() {
    local repo="Jeetchavan02/GitHeatmap"
    local app_name="GitHeatmap.app"
    local install_dir="/Applications"
    local verify_only=0
    local local_dmg=""

    while [ $# -gt 0 ]; do
        case "$1" in
            --verify-only) verify_only=1 ;;
            --dmg)
                [ $# -ge 2 ] || fail "--dmg needs a file path"
                local_dmg="$2"
                shift
                ;;
            *) fail "Unknown option: $1" ;;
        esac
        shift
    done

    [ "$(uname -s)" = "Darwin" ] || fail "GitHeatmap only runs on macOS."

    work_dir="$(mktemp -d)"
    mount_point=""
    trap cleanup EXIT

    # 1. Find the release's DMG and the digest GitHub recorded for it.
    step "Looking up the latest release"
    local release_json="$work_dir/release.json"
    curl -fsSL -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/$repo/releases/latest" -o "$release_json" \
        || fail "Could not reach GitHub to look up the release."

    local tag asset_name="" asset_url="" digest="" i=0 name
    tag="$(json_get "$release_json" tag_name)" || fail "Could not read the release details."
    while name="$(json_get "$release_json" "assets.$i.name")"; do
        case "$name" in
            *.dmg)
                asset_name="$name"
                asset_url="$(json_get "$release_json" "assets.$i.browser_download_url")"
                digest="$(json_get "$release_json" "assets.$i.digest" || true)"
                break
                ;;
        esac
        i=$((i + 1))
    done
    [ -n "$asset_name" ] || fail "Release $tag has no DMG."
    case "$digest" in
        sha256:*) digest="${digest#sha256:}" ;;
        *) fail "GitHub published no SHA-256 digest for $asset_name, so it cannot be verified." ;;
    esac
    pass "Found $asset_name ($tag)"

    # 2. Download, unless checking a local file.
    local dmg
    if [ -n "$local_dmg" ]; then
        [ -f "$local_dmg" ] || fail "File not found: $local_dmg"
        dmg="$local_dmg"
    else
        step "Downloading"
        dmg="$work_dir/$asset_name"
        curl -fL --progress-bar "$asset_url" -o "$dmg" || fail "Download failed."
    fi

    # 3. The file must be byte-for-byte what was published.
    step "Verifying the DMG"
    local actual
    actual="$(shasum -a 256 "$dmg" | awk '{print $1}')"
    [ "$actual" = "$digest" ] || fail "Checksum mismatch: this DMG is not the published file.
  Expected: $digest
  Got:      $actual"
    pass "SHA-256 matches the published digest"

    hdiutil verify -quiet "$dmg" 2>/dev/null || fail "The disk image is corrupted."
    pass "Disk image is intact"

    # 4. The app inside must be present and its signature must be unbroken.
    step "Verifying the app"
    mount_point="$work_dir/mount"
    mkdir "$mount_point"
    hdiutil attach -quiet -readonly -nobrowse -noautoopen -mountpoint "$mount_point" "$dmg" 2>/dev/null \
        || { mount_point=""; fail "Could not open the disk image."; }

    local source_app="$mount_point/$app_name"
    [ -d "$source_app" ] || fail "$app_name is missing from the DMG."
    codesign --verify --deep --strict "$source_app" 2>/dev/null \
        || fail "The app's code signature is invalid: its contents were altered after signing."
    pass "App signature is intact"

    if [ "$verify_only" -eq 1 ]; then
        printf '\nAll checks passed. Nothing was installed (--verify-only).\n'
        return 0
    fi

    # 5. Install. Copy first, so a failed copy leaves any existing app untouched.
    step "Installing to $install_dir"
    [ -w "$install_dir" ] || fail "No permission to write to $install_dir."
    local target="$install_dir/$app_name"
    local staged="$install_dir/.GitHeatmap.installing.$$"
    ditto "$source_app" "$staged" || { rm -rf "$staged"; fail "Could not copy the app."; }
    osascript -e 'quit app "GitHeatmap"' >/dev/null 2>&1 || true
    if [ -e "$target" ]; then
        rm -rf "$target" || { rm -rf "$staged"; fail "Could not replace the existing app."; }
    fi
    mv "$staged" "$target"
    pass "Installed $target"

    open "$target" || fail "Installed, but the app could not be opened."
    printf '\nDone! To add the widget, right-click your desktop and choose Edit Widgets, then search for GitHeatmap.\n'
}

cleanup() {
    if [ -n "${mount_point:-}" ]; then
        hdiutil detach -quiet "$mount_point" 2>/dev/null || hdiutil detach -quiet -force "$mount_point" 2>/dev/null || true
    fi
    rm -rf "${work_dir:-}"
}

json_get() { plutil -extract "$2" raw -o - "$1" 2>/dev/null; }
step() { printf '\n==> %s\n' "$1"; }
pass() { printf '  ok: %s\n' "$1"; }
fail() { printf '\nInstall stopped: %s\nNothing further was changed.\n' "$1" >&2; exit 1; }

main "$@"
