import QtQuick
import Caelestia.Config

Item {
    id: root

    property date shownDate
    property real offset: Tokens.padding.extraLarge

    property bool _repositioning: false
    property real translate
    property real opacity: 1

    property date _prevDate

    Component.onCompleted: root._prevDate = root.shownDate

    onShownDateChanged: {
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
