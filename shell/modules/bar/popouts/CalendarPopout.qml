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

    /// The day whose events are listed under the grid. Clicking a day moves it, which
    /// is what makes the grid and the list one control instead of two.
    property date selectedDate: new Date()
    readonly property var selectedEvents: CalendarEvents.eventsOn(root.selectedDate)

    readonly property string selectedLabel: root.isToday(root.selectedDate) ? qsTr("Today") : Qt.locale().toString(root.selectedDate, "ddd d MMM")

    function isSameDay(a: date, b: date): bool {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function isToday(date: date): bool {
        return root.isSameDay(date, new Date());
    }

    function isSelected(date: date): bool {
        return root.isSameDay(date, root.selectedDate);
    }

    function select(date: date): void {
        root.selectedDate = new Date(date.getFullYear(), date.getMonth(), date.getDate());
        // A trailing day belongs to the month it is shown in, so follow it there.
        if (date.getMonth() !== root.currMonth || date.getFullYear() !== root.currYear)
            root.viewDate = new Date(date.getFullYear(), date.getMonth(), 1);
    }

    function eventTime(event: var): string {
        if (event.allDay)
            return qsTr("All day");
        // Same 12/24-hour choice as the bar clock, so the two never disagree.
        return event.start.toLocaleString(Qt.locale(), Units.twelveHourClock ? "h:mm A" : "HH:mm");
    }

    function agendaHint(): string {
        if (!CalendarEvents.configured)
            return qsTr("No calendars yet - click to add one");
        if (CalendarEvents.errors.length > 0)
            return qsTr("Could not read %1 - click to check the address").arg(CalendarEvents.errors[0].source);

        return qsTr("No events");
    }

    /// Cheap when nothing changed: the script reuses its copy of the calendar and only
    /// revalidates it, so this is safe to run every time the popout is opened.
    function refreshOnOpen(): void {
        const popouts = root.popouts;
        if (!popouts)
            return;
        // Name first or flag first depends on how the popout was opened, so either
        // changing is enough for it to count as opened.
        if (popouts.currentName !== "clock")
            return;
        CalendarEvents.refresh();
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

    // Opening the calendar is the moment its contents matter, so that is when a stale
    // copy is re-read rather than only on the background timer.
    Connections {
        function onHasCurrentChanged(): void {
            root.refreshOnOpen();
        }

        function onCurrentNameChanged(): void {
            root.refreshOnOpen();
        }

        target: root.popouts
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
                            if (root.isSelected(dayItem.model.date))
                                return Colours.palette.m3onPrimary;
                            if (dayItem.model.today)
                                return Colours.palette.m3primary;
                            if (dayItem.model.date.getDay() === 0 || dayItem.model.date.getDay() === 6)
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
                        // The selected day already carries the indicator shape.
                        visible: !root.isSelected(dayItem.model.date) && CalendarEvents.hasEventsOn(dayItem.model.date)
                    }

                    StateLayer {
                        anchors.fill: parent
                        radius: Tokens.rounding.full
                        onClicked: root.select(dayItem.model.date)
                    }
                }
            }

            MaterialShape {
                id: selectionIndicator

                readonly property Item selectedItem: grid.contentItem.children.find(c => root.isSelected(c.model.date)) ?? null
                property Item day

                onSelectedItemChanged: {
                    if (selectedItem)
                        day = selectedItem;
                }

                x: day ? day.x + (day.width - implicitWidth) / 2 : 0
                y: day ? day.y + (day.height - implicitHeight) / 2 : 0

                implicitSize: day ? Math.max(day.implicitWidth, day.implicitHeight) + Tokens.padding.extraSmall * 2 * root.scaleOffset : 0
                shape: MaterialShape.Sunny

                clip: true
                color: Colours.palette.m3primary

                opacity: selectedItem ? 1 : 0

                Colouriser {
                    x: -selectionIndicator.x
                    y: -selectionIndicator.y

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
            Layout.topMargin: Tokens.spacing.medium * root.scaleOffset
            implicitHeight: 1
            color: Colours.palette.m3outlineVariant
        }

        // The day the indicator sits on, so the list below reads as that cell opened up
        // rather than as a separate feed.
        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium * root.scaleOffset
            text: root.selectedLabel
            color: Colours.palette.m3onSurface
            font: Tokens.font.body.builders.small.size(Tokens.font.body.builders.small.build().pointSize * root.fontScale).weight(Font.Medium).build()
            elide: Text.ElideRight
        }

        Repeater {
            model: root.selectedEvents.length > 0 ? root.selectedEvents : [null]

            delegate: Item {
                id: eventRow

                required property var modelData

                Layout.fillWidth: true
                Layout.topMargin: Tokens.spacing.extraSmall * root.scaleOffset
                implicitHeight: (eventRow.modelData ? eventText.implicitHeight : hint.implicitHeight)

                Column {
                    id: eventText

                    width: parent.width
                    spacing: 0
                    visible: eventRow.modelData !== null

                    Row {
                        width: parent.width
                        spacing: Tokens.spacing.small * root.scaleOffset

                        StyledText {
                            width: 74 * root.scaleOffset
                            text: eventRow.modelData ? root.eventTime(eventRow.modelData) : ""
                            color: Colours.palette.m3primary
                            font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width - 74 * root.scaleOffset - parent.spacing
                            text: eventRow.modelData?.summary ?? ""
                            color: Colours.palette.m3onSurface
                            font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        width: parent.width - 74 * root.scaleOffset - Tokens.spacing.small * root.scaleOffset
                        x: 74 * root.scaleOffset + Tokens.spacing.small * root.scaleOffset
                        text: eventRow.modelData?.location ?? ""
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.label.builders.small.size(Tokens.font.label.small.pointSize * root.fontScale).build()
                        elide: Text.ElideRight
                        visible: text.length > 0
                    }
                }

                StyledText {
                    id: hint

                    width: parent.width
                    visible: eventRow.modelData === null
                    text: root.agendaHint()
                    color: Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.builders.small.size(Tokens.font.body.small.pointSize * root.fontScale).build()
                    wrapMode: Text.Wrap
                }

                // Last, so it takes the click rather than the text above it, and it has
                // to be given the row's size: it is not positioned by the layout.
                StateLayer {
                    anchors.fill: parent
                    radius: Tokens.rounding.medium
                    disabled: eventRow.modelData !== null || CalendarEvents.configured
                    onClicked: root.openCalendarSettings()
                }
            }
        }
    }
}
