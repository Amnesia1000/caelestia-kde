#!/usr/bin/env bash

IS_ENABLED=$(kreadconfig6 --file kwinrc --group Plugins --key better_blur_dxEnabled)
if [ "$IS_ENABLED" = "true" ]; then
    BLUR_MATCHING=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurMatching)
    BLUR_NON_MATCHING=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key BlurNonMatching)
    WINDOW_CLASSES=$(kreadconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses)

    if [ -z "$BLUR_MATCHING" ]; then BLUR_MATCHING="true"; fi
    if [ -z "$BLUR_NON_MATCHING" ]; then BLUR_NON_MATCHING="false"; fi

    MODIFIED=false

    if [ "$BLUR_MATCHING" = "true" ] && [ "$BLUR_NON_MATCHING" = "false" ]; then
        if echo "$WINDOW_CLASSES" | grep -q '\bquickshell\b'; then
            NEW_CLASSES=$(echo "$WINDOW_CLASSES" | sed -E 's/\bquickshell\b//g' | sed 's/,,/,/g' | sed 's/^,//' | sed 's/,$//')
            kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses "$NEW_CLASSES"
            MODIFIED=true
        fi
    elif [ "$BLUR_MATCHING" = "false" ] && [ "$BLUR_NON_MATCHING" = "true" ]; then
        if ! echo "$WINDOW_CLASSES" | grep -q '\bquickshell\b'; then
            if [ -z "$WINDOW_CLASSES" ]; then
                NEW_CLASSES="quickshell"
            elif echo "$WINDOW_CLASSES" | grep -q ','; then
                NEW_CLASSES="$WINDOW_CLASSES,quickshell"
            else
                NEW_CLASSES="$WINDOW_CLASSES"$'\n'"quickshell"
            fi
            kwriteconfig6 --file kwinrc --group Effect-better-blur-dx --key WindowClasses "$NEW_CLASSES"
            MODIFIED=true
        fi
    fi

    if [ "$MODIFIED" = "true" ]; then
        qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
        qdbus6 org.kde.KWin /Effects reconfigureEffect better_blur_dx 2>/dev/null || true
    fi

    echo "BBDX_ENABLED"
fi
