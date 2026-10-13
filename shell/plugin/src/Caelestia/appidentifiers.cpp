#include <QCoreApplication>
#include <QString>
#include <QtGlobal>

namespace {

void setApplicationIdentifiers() {
    QCoreApplication::setOrganizationName(QStringLiteral("Caelestia"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("caelestia.dots"));
    QCoreApplication::setApplicationName(QStringLiteral("caelestia-shell"));
}

} // namespace

Q_CONSTRUCTOR_FUNCTION(setApplicationIdentifiers)
