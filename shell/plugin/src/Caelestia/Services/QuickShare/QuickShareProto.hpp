#pragma once

#include <google/protobuf/message_lite.h>

#include <QByteArray>

namespace caelestia::services {

inline QByteArray serialize(const google::protobuf::MessageLite& message) {
    QByteArray bytes;
    bytes.resize(static_cast<qsizetype>(message.ByteSizeLong()));
    if (!message.SerializeToArray(bytes.data(), static_cast<int>(bytes.size())))
        return {};
    return bytes;
}
}
