#pragma once

#include <QObject>
#include <QTcpSocket>

#include "QuickShareCrypto.hpp"
#include "offline_wire_formats.pb.h"
#include "wire_format.pb.h"

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

    /// Where a received file was written. Empty until the last chunk arrives.
    QString incomingFilePath() const { return m_incomingFilePath; }

    QString deviceName() const { return m_deviceName; }

signals:
    void stateChanged(State newState);
    void transferRequested(const QString& fileName, qint64 fileSize);
    void pinCodeReady(const QString& pinCode);
    void transferProgress(qint64 bytesSent, qint64 bytesTotal);
    /// The transfer ended, successfully or not. Emitted once per connection.
    void transferFinished(bool success);
    /// The socket is gone. The service drops its handle on this.
    void closed();

private slots:
    void onReadyRead();
    void onDisconnected();
    void onError(QAbstractSocket::SocketError socketError);

private:
    void connectSocket();
    void setState(State state);
    /// Reports the end of the transfer once: a file save and the peer's later
    /// disconnection both end the same transfer.
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
    void sendPayloadChunk(qint64 payloadId,
        location::nearby::connections::PayloadTransferFrame::PayloadHeader::PayloadType type, qint64 totalSize,
        qint64 offset, bool lastChunk, const QByteArray& body, const QString& fileName = {});
    void sendEncryptedSharingFrame(sharing::nearby::V1Frame::FrameType type);
    void sendEncryptedSharingFrame(const sharing::nearby::Frame& frame);
    /// Length-prefixes a frame sent before the handshake encrypts anything.
    void sendPlaintextFrame(const location::nearby::connections::OfflineFrame& frame);
    /// Seals a frame and length-prefixes the result.
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
    qint64 m_outgoingFileSize = 0;

    QMap<qint64, QByteArray> m_payloadBuffers;

    QByteArray m_fileBuffer;
    bool m_fileTransferActive = false;
};

} // namespace caelestia::services
