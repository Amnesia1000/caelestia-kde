// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <qobject.h>
#include <qqmlintegration.h>
#include <qvariantlist.h>

namespace caelestia::services {

/// Bridges KDE's KRunner into the launcher, so shell search reaches whatever the
/// system's runners provide rather than only the shell's own sources: files
/// (Baloo), recent documents, places, bookmarks, web shortcuts, the dictionary,
/// unit and currency conversion, settings modules and applications.
///
/// KRunner's D-Bus service only exposes UI-control methods, so results have to
/// come from the library. On a system without libKF6Runner this object still
/// exists but reports `available == false`, which is why the QML side can import
/// it unconditionally.
class KRunnerBridge : public QObject {
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)

public:
    explicit KRunnerBridge(QObject* parent = nullptr);
    ~KRunnerBridge() override;

    [[nodiscard]] bool available() const;
    [[nodiscard]] bool busy() const;
    [[nodiscard]] QVariantList results() const;

    /// Starts a query. Runner results arrive in batches, so `results` keeps
    /// growing until `busy` returns to false.
    Q_INVOKABLE void search(const QString& text);
    Q_INVOKABLE void clear();
    /// Runs the result at `index`, through `actionId` when it names one of that
    /// result's secondary actions and through its default action otherwise.
    Q_INVOKABLE void run(int index, const QString& actionId);

signals:
    void busyChanged();
    void resultsChanged();

private:
    void publishResults();
    void setBusy(bool busy);

    QObject* m_manager = nullptr;
    QVariantList m_results;
    /// Maps a published row to its position in KRunner's own match list, which
    /// can hold entries this bridge does not show.
    QList<int> m_sourceIndices;
    bool m_busy = false;
};

} // namespace caelestia::services
