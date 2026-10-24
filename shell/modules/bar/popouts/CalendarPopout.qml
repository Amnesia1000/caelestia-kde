pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import M3Shapes
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.modules.nexus

StyledRect {
    id: root

    required property PopoutState popouts
    property bool _isSidebarOpen: false
    property real scaleOffset: 1.0
    property real fontScale: 1.0

    property date viewDate: new Date()
    readonly property int currMonth: viewDate.getMonth()
    readonly property int currYear: viewDate.getFullYear()

    /// One row per day header and per event, so the agenda stays a single flat list.
    readonly property var agendaRows: {
        const rows = [];
        for (const group of CalendarEvents.upcoming(3)) {
            rows.push({ kind: "day", label: root.dayLabel(group.date) });
            for (const event of group.events)
                rows.push({
                    kind: "event",
                    label: event.allDay ? qsTr("All day") : Qt.formatTime(event.start, "hh:mm"),
                    event: event
                });
        }
        if (rows.length === 0)
            rows.push({ kind: "empty", label: "" });
        return rows;
    }

    function dayLabel(date: date): string {
        const now = new Date();
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const day = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        const days = Math.round((day - midnight) / 86400000);
        if (days === 0)
            return qsTr("Today");
        if (days === 1)
            return qsTr("Tomorrow");

        return Qt.locale().toString(date, "ddd d MMM");
    }

    function rowText(row: var): string {
        if (row.kind === "day")
            return "";
        if (row.kind === "empty")
            return root.agendaHint();

        return row.event.location ? `${row.event.summary} · ${row.event.location}` : row.event.summary;
    }

    function agendaHint(): string {
        if (!CalendarEvents.configured)
            return qsTr("No calendars yet — click to add one");
        if (CalendarEvents.errors.length > 0)
            return qsTr("Could not read %1 — click to check the address").arg(CalendarEvents.errors[0].source);

        return qsTr("Nothing scheduled");
    }

    /// The empty agenda is the only place a first-time user meets this feature, so it
    /// leads to the page that fills it rather than naming a menu they have to find.
    function openCalendarSettings(): void {
        const pageIdx = PageDictionary.pages.findIndex(page => page.key === "services");
        if (pageIdx < 0)
            return;

        if (root.popouts)
            root.popouts.hasCurrent = false;
        WindowFactory.create(null, {
            initialPageIdx: pageIdx,
            initialSubPageIdx: PageDictionary.subPageIdxFor("services/CalendarPage.qml")
        });
    }

    function shiftMonth(delta: int): void {
        root.viewDate = new Date(root.currYear, root.currMonth + delta, 1);
    }

    function goToToday(): void {
        root.viewDate = new Date();
    }

    implicitWidth: 497 * root.scaleOffset
    implicitHeight: inner.implicitHeight + Tokens.padding.large * 2 * root.scaleOffset
    radius: Tokens.rounding.extraLarge * root.scaleOffset
    color: Colours.tPalette.m3surfaceContainer

    CalendarMonthSlide {
        id: monthSlide

        shownDate: root.viewDate
        offset: Tokens.padding.extraLarge * root.scaleOffset
    }

    CustomMouseArea {
        function onWheel(event: WheelEvent): void {
            if (event.angleDelta.y > 0)
                root.shiftMonth(-1);
            else if (event.angleDelta.y < 0)
                root.shiftMonth(1);
        }

        anchors.fill: parent
        acceptedButtons: Qt.MiddleButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton) {
                root.goToToday();
            } else if (mouse.button === Qt.RightButton) {
                root.popouts.currentName = "clockcontext";
            }
        }
    }

    ColumnLayout {
        id: inner

        x: Tokens.padding.large * root.scaleOffset
        y: Tokens.padding.large * root.scaleOffset
        width: root.width - Tokens.padding.large * 2 * root.scaleOffset
        spacing: Tokens.spacing.extraSmall * root.scaleOffset

        RowLayout {
            id: monthNavigationRow

            Layout.fillWidth: true
            spacing: Tokens.spacing.extraSmall * root.scaleOffset

            IconButton {
                isRound: true
                icon: "chevron_left"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).size(Tokens.font.icon.builders.small.build().pointSize * root.fontScale).build()
                padding: Tokens.padding.small * root.scaleOffset
                onClicked: root.shiftMonth(-1)
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                implicitWidth: monthYearDisplay.implicitWidth + Tokens.padding.large * 2 * root.scaleOffset
                implicitHeight: monthYearDisplay.implicitHeight + Tokens.padding.extraSmall * 2 * root.scaleOffset

                StateLayer {
                    color: Colours.palette.m3primary
                    radius: pressed ? Tokens.rounding.small * root.scaleOffset : height / 2
                    disabled: {
                        const now = new Date();
                        return root.currMonth === now.getMonth() && root.currYear === now.getFullYear();
                    }
                    onClicked: root.goToToday()

                    Behavior on radius {
                        Anim {
                            type: Anim.DefaultEffects
                        }
                    }
                }

                StyledText {
                    id: monthYearDisplay

                    opacity: monthSlide.animOpacity
                    transform: Translate {
                        x: monthSlide.animTranslate
                    }

                    anchors.centerIn: parent
                    text: grid.title
                    color: Colours.palette.m3primary
                    font: Tokens.font.title.builders.small.capitalisation(Font.Capitalize).size(Tokens.font.title.builders.small.build().pointSize * root.fontScale).build()
                }
            }

            IconButton {
                isRound: true
                icon: "chevron_right"
                type: IconButton.Text
                font: Tokens.font.icon.builders.small.weight(Font.Bold).size(Tokens.font.icon.builders.small.build().pointSize * root.fontScale).build()
                padding: Tokens.padding.small * root.scaleOffset
                onClicked: root.shiftMonth(1)
            }
        }

        DayOfWeekRow {
            id: daysRow

            Layout.fillWidth: true
            locale: grid.locale

            delegate: StyledText {
                required property var model

                horizontalAlignment: Text.AlignHCenter
                text: model.shortName
                font: Tokens.font.body.builders.small.weight(Font.Medium).size(Tokens.font.body.builders.small.build().pointSize * root.fontScale).build()
                color: (model.day === 0 || model.day === 6) ? Colours.palette.m3tertiary : Colours.palette.m3onSurface
                renderType: Text.QtRendering
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: grid.implicitHeight

            opacity: monthSlide.animOpacity
            transform: Translate {
                x: monthSlide.animTranslate
            }

            MonthGrid {
                id: grid

                month: root.currMonth
                year: root.currYear

                anchors.fill: parent

                spacing: 3 * root.scaleOffset
                locale: Qt.locale()

                delegate: Item {
                    id: dayItem

                    required property var model

                    implicitWidth: implicitHeight
                    implicitHeight: text.implicitHeight + Tokens.padding.small * root.scaleOffset

                    StyledText {
                        id: text

                        anchors.centerIn: parent

                        horizontalAlignment: Text.AlignHCenter
                        text: grid.locale.toString(dayItem.model.day)
                        color: {
                            const dayOfWeek = dayItem.model.date.getDay();
                            if (dayOfWeek === 0 || dayOfWeek === 6)
                                return Colours.palette.m3tertiary;

                            return Colours.palette.m3onSurfaceVariant;
                        }
                        opacity: dayItem.model.today || dayItem.model.month === grid.month ? 1 : 0.4
                        font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
                        renderType: Text.QtRendering
                    }

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        implicitWidth: 3 * root.scaleOffset
                        implicitHeight: 3 * root.scaleOffset
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        visible: CalendarEvents.hasEventsOn(dayItem.model.date)
                    }
                }
            }

            MaterialShape {
                id: todayIndicator

                readonly property Item todayItem: grid.contentItem.children.find(c => c.model.today) ?? null
                property Item today

                onTodayItemChanged: {
                    if (todayItem)
                        today = todayItem;
                }

                x: today ? today.x + (today.width - implicitWidth) / 2 : 0
                y: today ? today.y + (today.height - implicitHeight) / 2 : 0

                implicitSize: today ? Math.max(today.implicitWidth, today.implicitHeight) + Tokens.padding.extraSmall * 2 * root.scaleOffset : 0
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary

                opacity: todayItem ? 1 : 0

                Colouriser {
                    x: -todayIndicator.x
                    y: -todayIndicator.y

                    implicitWidth: grid.width
                    implicitHeight: grid.height

                    source: grid
                    sourceColor: Colours.palette.m3onSurface
                    colorizationColor: Colours.palette.m3onPrimary
                }

                Behavior on x {
                    Anim {}
                }

                Behavior on y {
                    Anim {}
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.small * root.scaleOffset
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.extraSmall * root.scaleOffset
            text: qsTr("Upcoming")
            color: Colours.palette.m3primary
            font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
        }

        Repeater {
            model: root.agendaRows

            delegate: Item {
                id: agendaRow

                required property var modelData

                Layout.fillWidth: true
                implicitHeight: rowLayout.implicitHeight

                RowLayout {
                    id: rowLayout

                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: Tokens.spacing.small * root.scaleOffset

                    StyledText {
                        Layout.preferredWidth: 84 * root.scaleOffset
                        text: agendaRow.modelData.label ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }

                    Rectangle {
                        implicitWidth: 4 * root.scaleOffset
                        implicitHeight: 4 * root.scaleOffset
                        radius: Tokens.rounding.full
                        color: Colours.palette.m3primary
                        visible: agendaRow.modelData.kind === "event"
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.rowText(agendaRow.modelData)
                        color: agendaRow.modelData.kind === "event" ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
                        elide: Text.ElideRight
                    }
                }

                // Last, so it takes the click rather than the text above it, and it has
                // to be given the row's size: it is not positioned by the layout.
                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    disabled: agendaRow.modelData.kind !== "empty"
                    onClicked: root.openCalendarSettings()
                }
            }
        }
    }
}
