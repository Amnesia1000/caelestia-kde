#pragma once

#include <QFile>
#include <QMap>
#include <QObject>
#include <QTcpSocket>

#include "QuickShareCrypto.hpp"
#ifndef Q_MOC_RUN
#include "offline_wire_formats.pb.h"
#include "wire_format.pb.h"
#endif

namespace caelestia::services {

class QuickShareConnection : public QObject {
    Q_OBJECT

public:
    enum State {
        Disconnected,
        Connecting,
        OfflineFrameExchange,
        Ukey2Handshake,
        PostHandshake,
        PairedKeyExchange,
        ConnectionAccepted,
        Transferring
    };

    explicit QuickShareConnection(QTcpSocket* socket, QObject* parent = nullptr);
    explicit QuickShareConnection(const QString& host, int port, QObject* parent = nullptr);
    ~QuickShareConnection() override;

    void sendFile(const QString& filePath);
    void acceptTransfer();
    void rejectTransfer();

    QString incomingFileName() const { return m_incomingFileName; }

    QString incomingFilePath() const { return m_incomingFilePath; }

    QString deviceName() const { return m_deviceName; }

signals:
    void stateChanged(State newState);
    void transferRequested(const QString& fileName, qint64 fileSize);
    void pinCodeReady(const QString& pinCode);
    void transferProgress(qint64 bytesSent, qint64 bytesTotal);
    void transferFinished(bool success);
    void closed();

private slots:
    void onReadyRead();
    void onDisconnected();
    void onError(QAbstractSocket::SocketError socketError);

private:
    class PayloadBuffer {
    public:
        bool append(qint64 offset, const QByteArray& body, bool last) {
            if (offset != m_data.size())
                return false;

            m_data.append(body);
            m_complete = last;
            return true;
        }

        bool complete() const { return m_complete; }

        qint64 size() const { return m_data.size(); }

        const QByteArray& data() const { return m_data; }

        void clear() {
            m_data.clear();
            m_complete = false;
        }

    private:
        QByteArray m_data;
        bool m_complete = false;
    };

    void connectSocket();
    void setState(State state);
    void finishTransfer(bool success);

    void handleOfflineFrame(const QByteArray& data);
    void handleUkey2(const QByteArray& data);
    void handlePostHandshake(const QByteArray& data);
    void handleEncryptedFrame(const QByteArray& data);
    void handleSharingFrame(const sharing::nearby::Frame& frame);
    void handlePayloadTransfer(const location::nearby::connections::PayloadTransferFrame& packet);
    void handleFileChunk(const location::nearby::connections::PayloadTransferFrame& packet, const QByteArray& body);
    void handleByteChunk(const location::nearby::connections::PayloadTransferFrame& packet, const QByteArray& body);
    void saveIncomingFile();

    void sendConnectionRequest();
    void sendConnectionResponse();
    void sendDisconnection();
    void sendFilePayload();
    void pumpOutgoingFile();
    void sendPayloadChunk(qint64 payloadId,
        location::nearby::connections::PayloadTransferFrame::PayloadHeader::PayloadType type, qint64 totalSize,
        qint64 offset, bool lastChunk, const QByteArray& body, const QString& fileName = {});
    void sendEncryptedSharingFrame(sharing::nearby::V1Frame::FrameType type);
    void sendEncryptedSharingFrame(const sharing::nearby::Frame& frame);
    void sendPlaintextFrame(const location::nearby::connections::OfflineFrame& frame);
    void sendSecureFrame(const location::nearby::connections::OfflineFrame& frame);

    QTcpSocket* m_socket;
    State m_state = Disconnected;
    bool m_finished = false;
    int m_sendSeq = 1;
    QuickShareCrypto m_crypto;
    QByteArray m_buffer;

    QString m_incomingFileName;
    QString m_incomingFilePath;
    qint64 m_incomingFileSize = 0;
    QString m_deviceName;

    qint64 m_outgoingFilePayloadId = 0;
    QString m_outgoingFilePath;
    QString m_outgoingFileName;
    qint64 m_outgoingFileSize = 0;
    qint64 m_outgoingOffset = 0;
    QFile m_outgoingFile;
    bool m_outgoingFileQueued = false;

    QMap<qint64, PayloadBuffer> m_payloadBuffers;

    PayloadBuffer m_incomingFile;
};
}
