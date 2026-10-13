// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QQmlEngine>
#include <QSet>
#include <QTimer>

namespace caelestia::services {

class ScreenEdges : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    QML_ELEMENT
    QML_SINGLETON

public:
    enum Corner {
        TopRight = 1,
        BottomRight = 3,
        BottomLeft = 5,
        TopLeft = 7,
    };
    Q_ENUM(Corner)

    explicit ScreenEdges(QObject* parent = nullptr);
    ~ScreenEdges() override;

    bool available() const;

    Q_INVOKABLE void claim(int corner);

    Q_INVOKABLE void release(int corner);

    Q_INVOKABLE bool holds(int corner) const;

private:
    struct StolenEdge {
        int corner = 0;
        QHash<QString, QHash<QString, QString>> entries;
    };

    void recoverFromCrash();
    void stealCorner(int corner);
    void restoreCorner(const StolenEdge& stolen);
    void restoreAll();

    QJsonObject toJson(const StolenEdge& stolen) const;
    StolenEdge fromJson(const QJsonObject& obj) const;

    void persist() const;
    void scheduleReconfigure();

    QHash<int, StolenEdge> m_stolen;
    QTimer* m_reconfigureTimer;
    bool m_restored = false;
};

} // namespace caelestia::services
