#pragma once

#include <QByteArray>
#include <QList>
#include <QString>

namespace caelestia::services::endpointinfo {

QByteArray encode(const QString& deviceName);

QString deviceName(const QByteArray& record);

bool isVisible(const QByteArray& record);

QList<QByteArray> txtRecord(const QString& deviceName);

QString toBase64Url(const QByteArray& bytes);

QByteArray fromBase64Url(const QByteArray& encoded);

} // namespace caelestia::services::endpointinfo
