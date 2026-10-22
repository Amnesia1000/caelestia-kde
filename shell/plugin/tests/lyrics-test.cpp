#include <QtCore>
#include <QtNetwork>
#include <QtQml>
#include <QtTest>

#include "../src/Caelestia/Config/rootnodes.hpp"
#include "lyrics.hpp"
#include "lyricsmatching.hpp"

namespace caelestia::services {

struct Response {
    QByteArray body = "{}";
    QNetworkReply::NetworkError error = QNetworkReply::NoError;
    int status = 200;
    int delay = 0;
};

class FakeReply : public QNetworkReply {
public:
    FakeReply(const QNetworkRequest& request, Response response, QObject* parent)
        : QNetworkReply(parent)
        , m_body(response.body) {
        setRequest(request);
        setUrl(request.url());
        setAttribute(QNetworkRequest::HttpStatusCodeAttribute, response.status);
        open(QIODevice::ReadOnly);
        QTimer::singleShot(response.delay, this, [this, response] {
            if (isFinished())
                return;
            if (response.error != NoError)
                setError(response.error, QStringLiteral("simulated network error"));
            setFinished(true);
            emit readyRead();
            emit finished();
        });
    }

    void abort() override {
        if (!isFinished()) {
            setError(OperationCanceledError, QStringLiteral("cancelled"));
            setFinished(true);
            emit finished();
        }
    }

    qint64 bytesAvailable() const override { return m_body.size() + QNetworkReply::bytesAvailable(); }

protected:
    qint64 readData(char* data, qint64 maximum) override {
        if (m_body.isEmpty())
            return -1;
        const auto count = std::min<qint64>(maximum, m_body.size());
        memcpy(data, m_body.constData(), count);
        m_body.remove(0, count);
        return count;
    }

private:
    QByteArray m_body;
};

class FakeNetwork : public QNetworkAccessManager {
public:
    using QNetworkAccessManager::QNetworkAccessManager;
    QList<QUrl> requests;
    std::function<Response(const QUrl&)> respond;

protected:
    QNetworkReply* createRequest(Operation, const QNetworkRequest& request, QIODevice*) override {
        requests.append(request.url());
        return new FakeReply(request, respond ? respond(request.url()) : Response{}, this);
    }
};

static QByteArray track(int id = 42, const QString& title = QStringLiteral("Example"), double duration = 200) {
    return QJsonDocument(
        QJsonObject{ { "id", id }, { "trackName", title }, { "artistName", "Artist" }, { "duration", duration },
            { "syncedLyrics", "[00:00.00]First line\n[00:10.00]Second line" } })
        .toJson();
}

class LyricsTest : public QObject {
    Q_OBJECT
    QTemporaryDir m_dir;

    FakeNetwork* network(Lyrics& lyrics) {
        delete lyrics.m_nam;
        auto* fake = new FakeNetwork(&lyrics);
        lyrics.m_nam = fake;
        return fake;
    }

    void prepare(Lyrics& lyrics, const QString& title = QStringLiteral("Example")) {
        lyrics.m_artist = QStringLiteral("Artist");
        lyrics.m_title = title;
        lyrics.m_duration = 200;
        lyrics.m_preferredBackend = LyricsBackend::LRCLIB;
    }

private slots:

    void initTestCase() {
        QVERIFY(m_dir.isValid());
        qputenv("XDG_CONFIG_HOME", (m_dir.path() + "/config").toUtf8());
        qputenv("XDG_STATE_HOME", (m_dir.path() + "/state").toUtf8());
        qputenv("XDG_CACHE_HOME", (m_dir.path() + "/cache").toUtf8());
        config::ConfigSingleton::instance()->paths()->set_lyricsDir(m_dir.path() + "/local");
    }

    void init() {
        QDir(m_dir.path() + "/cache").removeRecursively();
        QDir(m_dir.path() + "/state").removeRecursively();
    }

    void matchingPreservesRecordings() {
        using namespace lyricsmatching;
        QVERIFY(score("Example (Official Music Video)", "Artist - Topic", 200, "Example", "Artist", 201) > 0);
        QVERIFY(score("Example", "Artist", 200, "Different", "Artist", 200) < 0);
        QVERIFY(score("Example (Live)", "Artist", 200, "Example", "Artist", 200) < 0);
        QVERIFY(score("Example (Remix)", "Artist", 200, "Example", "Artist", 200) < 0);
        QVERIFY(score("Example", "Artist", 200, "Example", "Another Artist", 290) < 0);
        QVERIFY(score("Example", "Artist", 0, "Example", "Artist", 0) > 0);
        QVERIFY(score("Example", "", 200, "Example", "Artist", 200) < 0);
        QVERIFY(score(QString::fromUtf8("دل"), "Artist", 200, QString::fromUtf8("دل"), "Artist", 200) > 0);
    }

    void refreshRestoresTheSameCandidate() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        fake->respond = [](const QUrl& url) {
            return Response{ url.path() == "/api/get" ? track() : QByteArray("[]") };
        };
        lyrics.doLoad();
        QTRY_VERIFY(lyrics.hasLyrics());
        QCOMPARE(lyrics.selectedCandidate().id(), QStringLiteral("42"));
        lyrics.refresh();
        QTest::qWait(100);
        QTRY_VERIFY(!lyrics.loading());
        QVERIFY(lyrics.hasLyrics());
        QCOMPARE(lyrics.lyrics().size(), 2);
    }

    void ranksSearchAfterAnExactMiss() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics, "Example (Official Video)");
        fake->respond = [](const QUrl& url) {
            if (url.path() == "/api/get")
                return Response{ "{}", QNetworkReply::ContentNotFoundError, 404 };
            if (url.path() == "/api/search")
                return Response{ "[" + track(1, "Example (Live)") + "," + track(2, "Example", 201) + "]" };
            return Response{};
        };
        lyrics.doLoad();
        QTRY_VERIFY(!lyrics.loading());
        QVERIFY(lyrics.hasLyrics());
        QCOMPARE(lyrics.selectedCandidate().id(), QStringLiteral("2"));
    }

    void failedSavedCandidateFallsBack() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        lyrics.m_lyricsMap.insert(lyrics.trackKey(), QJsonObject{ { "backend", "LRCLIB" }, { "id", "999" } });
        fake->respond = [](const QUrl& url) {
            if (url.path() == "/api/get/999")
                return Response{ "{}", QNetworkReply::ContentNotFoundError, 404 };
            return Response{ url.path() == "/api/get" ? track() : QByteArray("[]") };
        };
        lyrics.doLoad();
        QTRY_VERIFY(!lyrics.loading());
        QVERIFY(lyrics.hasLyrics());
        QCOMPARE(lyrics.selectedCandidate().id(), QStringLiteral("42"));
    }

    void netEaseRejectsAnotherSongByTheSameArtist() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        lyrics.m_preferredBackend = LyricsBackend::NetEase;
        fake->respond = [](const QUrl& url) {
            if (url.path() == "/api/search/get") {
                QJsonArray songs;
                for (int id : { 1, 2 }) {
                    songs.append(QJsonObject{ { "id", id }, { "name", id == 1 ? "Different" : "Example" },
                        { "duration", 200000 }, { "artists", QJsonArray{ QJsonObject{ { "name", "Artist" } } } } });
                }
                return Response{
                    QJsonDocument(QJsonObject{ { "result", QJsonObject{ { "songs", songs } } } }).toJson()
                };
            }
            if (url.path() == "/api/song/lyric")
                return Response{ R"({"lrc":{"lyric":"[00:00.00]Correct song"}})" };
            return Response{ "[]" };
        };
        lyrics.doLoad();
        QTRY_VERIFY(!lyrics.loading());
        QVERIFY(lyrics.hasLyrics());
        QCOMPARE(lyrics.selectedCandidate().id(), QStringLiteral("2"));
    }

    void searchRejectsDifferentRecordings() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        fake->respond = [](const QUrl& url) {
            if (url.path() == "/api/get")
                return Response{ "{}", QNetworkReply::ContentNotFoundError, 404 };
            if (url.path() == "/api/search")
                return Response{ "[" + track(1, "Example (Live)") + "," + track(2, "Example", 300) + "]" };
            return Response{ "[]" };
        };
        lyrics.doLoad();
        QTRY_VERIFY(!lyrics.loading());
        QVERIFY(!lyrics.hasLyrics());
    }

    void transientFailureRetriesOnce() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        int attempts = 0;
        fake->respond = [&attempts](const QUrl& url) {
            if (url.path() != "/api/get")
                return Response{ "[]" };
            if (++attempts == 1)
                return Response{ "{}", QNetworkReply::TimeoutError };
            return Response{ track() };
        };
        lyrics.doLoad();
        QTRY_VERIFY(lyrics.hasLyrics());
        QCOMPARE(attempts, 2);
    }

    void retriesAreBounded() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        int attempts = 0;
        fake->respond = [&attempts](const QUrl& url) {
            if (url.path() == "/api/get") {
                ++attempts;
                return Response{ "{}", QNetworkReply::TimeoutError };
            }
            return Response{ "[]" };
        };
        lyrics.doLoad();
        QTRY_VERIFY(!lyrics.loading());
        QCOMPARE(attempts, 2);
        QVERIFY(!lyrics.hasLyrics());
    }

    void clearingTrackCancelsPendingRetry() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        fake->respond = [](const QUrl&) {
            return Response{ "{}", QNetworkReply::TimeoutError };
        };
        lyrics.doLoad();
        QTest::qWait(20);
        lyrics.clearTrack();
        const auto count = fake->requests.size();
        QTest::qWait(850);
        QCOMPARE(fake->requests.size(), count);
        QVERIFY(!lyrics.hasLyrics());
        QVERIFY(!lyrics.loading());
    }

    void lateMetadataReplacesPendingRequests() {
        Lyrics lyrics;
        auto* fake = network(lyrics);
        prepare(lyrics);
        fake->respond = [](const QUrl& url) {
            if (url.path() == "/api/get")
                return Response{ track(), QNetworkReply::NoError, 200, 200 };
            return Response{ "[]" };
        };
        lyrics.doLoad();
        lyrics.setTrack("Artist", "Next", "Album", 210);
        lyrics.clearTrack();
        QTest::qWait(300);
        QVERIFY(!lyrics.loading());
        QVERIFY(!lyrics.hasLyrics());
        // clearTrack must also stop the metadata debounce timer.
        QCOMPARE(fake->requests.size(), 3);
    }
};

} // namespace caelestia::services

QTEST_GUILESS_MAIN(caelestia::services::LyricsTest)
#include "lyrics-test.moc"
