#!/usr/bin/env bash

IGNORE_CLASSES=(
    krunner
    yakuake
    spectacle
    kded5
    xwaylandvideobridge
    plasmashell
    ksplashqml
    org.kde.plasmashell
    org.kde.polkit-kde-authentication-agent-1
    quickshell
    org.quickshell
    org.pulseaudio.pavucontrol
    com.saivert.pwvucontrol
    yad
    yad-icon-browser
    system-config-printer
    nwg-look
    org.gnome.Settings
    org.gnome.FileRoller
    file-roller
    blueman-manager
    guifetch
    wev
    zenity
    feh
    imv
    swappy
)

has_ignore_class() {
    local entry
    while IFS= read -r entry; do
        if [[ "${entry//[[:space:]]/}" == "$2" ]]; then
            return 0
        fi
    done < <(printf '%s\n' "$1" | tr ',' '\n')
    return 1
}

IGNORE_CLASS=$(kreadconfig6 --file kwinrc --group Script-krohnkite --key ignoreClass 2>/dev/null)
NEW_IGNORE="$IGNORE_CLASS"
for class in "${IGNORE_CLASSES[@]}"; do
    if ! has_ignore_class "$NEW_IGNORE" "$class"; then
        NEW_IGNORE="${NEW_IGNORE:+$NEW_IGNORE,}$class"
    fi
done
kwriteconfig6 --file kwinrc --group Script-krohnkite --key ignoreClass "$NEW_IGNORE"

kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapBetween 10
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapBottom 4
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapLeft 4
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapRight 4
kwriteconfig6 --file kwinrc --group Script-krohnkite --key screenGapTop 4

kwriteconfig6 --file kwinrc --group Script-krohnkite --key binaryTreeLayoutOrder 1
kwriteconfig6 --file kwinrc --group Script-krohnkite --key cascadeLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key columnsLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key monocleLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key quarterLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key spiralLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key spreadLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key stackedLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key stairLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key threeColumnLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key tileLayoutOrder 0
kwriteconfig6 --file kwinrc --group Script-krohnkite --key floatingLayoutOrder 2

echo "StartupTasks: Updated Krohnkite exceptions, configured layouts and shortcuts"

exit 1
