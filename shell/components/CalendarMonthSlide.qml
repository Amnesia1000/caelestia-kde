import QtQuick
import Caelestia.Config

// The month-change motion a calendar shares. The incoming month is parked at the side the
// user came from and slid in, so a fast flick retargets the two Behaviours instead of
// replaying a fixed out-then-in sequence.
//
// A calendar binds `shownDate` to whichever date it displays and drives its own content from
// `translate` and `opacity`; nothing else about the change is its business.
Item {
    id: root

    // The date on screen. Assigning it slides from the month shown before to this one.
    property date shownDate
    // How far the parked month sits, before the direction. A caller on a scaled screen
    // multiplies its padding token itself.
    property real offset: Tokens.padding.extraLarge

    // Set while the incoming month is parked off to one side, so the Behaviours below let
    // that reposition land instead of animating it.
    property bool _repositioning: false
    property real translate
    property real opacity: 1

    // The month the change came from. Only the change reads it, which is what lets the
    // direction survive `shownDate` already holding the month being slid to — so it is a
    // plain property rather than a binding to `shownDate`, which would only hand back the
    // new value.
    property date _prevDate

    Component.onCompleted: root._prevDate = root.shownDate

    onShownDateChanged: {
        // Parked opposite the direction of travel, so the month appears to come from the
        // side the user moved towards.
        const parked = offset * (shownDate > _prevDate ? 1 : -1);
        _prevDate = shownDate;

        _repositioning = true;
        translate = parked;
        opacity = 0;
        _repositioning = false;
        translate = 0;
        opacity = 1;
    }

    Behavior on translate {
        enabled: !root._repositioning

        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on opacity {
        enabled: !root._repositioning

        Anim {
            type: Anim.FastEffects
        }
    }
}
