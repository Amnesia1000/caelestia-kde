// SPDX-License-Identifier: GPL-3.0-only
#include "krunnerbridge.hpp"

#ifdef CAELESTIA_HAVE_KRUNNER
#include <KRunner/Action>
#include <KRunner/QueryMatch>
#include <KRunner/RunnerManager>
#include <qvariantmap.h>
#endif

namespace caelestia::services {

KRunnerBridge::KRunnerBridge(QObject* parent): QObject(parent) {
#ifdef CAELESTIA_HAVE_KRUNNER
    auto* manager = new KRunner::RunnerManager(this);
    m_manager = manager;

    connect(manager, &KRunner::RunnerManager::matchesChanged, this, &KRunnerBridge::publishResults);
    connect(manager, &KRunner::RunnerManager::queryingChanged, this, [this] { setBusy(busy()); });
#endif
}

KRunnerBridge::~KRunnerBridge() = default;

bool KRunnerBridge::available() const {
#ifdef CAELESTIA_HAVE_KRUNNER
    return true;
#else
    return false;
#endif
}

bool KRunnerBridge::busy() const {
    return m_busy;
}

QVariantList KRunnerBridge::results() const {
    return m_results;
}

void KRunnerBridge::search(const QString& text) {
#ifdef CAELESTIA_HAVE_KRUNNER
    const auto trimmed = text.trimmed();
    if (trimmed.isEmpty()) {
        clear();
        return;
    }

    static_cast<KRunner::RunnerManager*>(m_manager)->launchQuery(trimmed);
#else
    Q_UNUSED(text)
#endif
}

void KRunnerBridge::clear() {
#ifdef CAELESTIA_HAVE_KRUNNER
    static_cast<KRunner::RunnerManager*>(m_manager)->reset();
#endif

    if (m_results.isEmpty() && m_sourceIndices.isEmpty())
        return;

    m_results.clear();
    m_sourceIndices.clear();
    emit resultsChanged();
}

void KRunnerBridge::run(int index, const QString& actionId) {
#ifdef CAELESTIA_HAVE_KRUNNER
    if (index < 0 || index >= m_sourceIndices.size())
        return;

    auto* manager = static_cast<KRunner::RunnerManager*>(m_manager);
    const auto matches = manager->matches();
    const int source = m_sourceIndices.at(index);
    if (source < 0 || source >= matches.size())
        return;

    const auto match = matches.at(source);
    KRunner::Action chosen;
    for (const auto& action : match.actions()) {
        if (action.id() == actionId) {
            chosen = action;
            break;
        }
    }

    manager->run(match, chosen);
#else
    Q_UNUSED(index)
    Q_UNUSED(actionId)
#endif
}

void KRunnerBridge::publishResults() {
#ifdef CAELESTIA_HAVE_KRUNNER
    const auto matches = static_cast<KRunner::RunnerManager*>(m_manager)->matches();

    QVariantList next;
    QList<int> nextIndices;
    next.reserve(matches.size());
    nextIndices.reserve(matches.size());

    for (int i = 0; i < matches.size(); ++i) {
        const auto& match = matches.at(i);
        if (!match.isValid())
            continue;

        QVariantList actions;
        for (const auto& action : match.actions()) {
            if (action.id().isEmpty())
                continue;
            actions.append(QVariantMap{
                {QStringLiteral("id"), action.id()},
                {QStringLiteral("text"), action.text()},
            });
        }

        next.append(QVariantMap{
            {QStringLiteral("text"), match.text()},
            {QStringLiteral("subtext"), match.subtext()},
            {QStringLiteral("icon"), match.iconName()},
            {QStringLiteral("relevance"), match.relevance()},
            {QStringLiteral("actions"), actions},
        });
        nextIndices.append(i);
    }

    m_results = next;
    m_sourceIndices = nextIndices;
    emit resultsChanged();
#else
    if (m_results.isEmpty())
        return;
    m_results.clear();
    emit resultsChanged();
#endif
}

void KRunnerBridge::setBusy(bool busy) {
    if (m_busy == busy)
        return;
    m_busy = busy;
    emit busyChanged();
}

} // namespace caelestia::services
