#pragma once

#include <QByteArray>
#include <QObject>
#include <QScopedPointer>
#include <QString>

class QNetworkAccessManager;
class QNetworkReply;
class QFile;
class QCryptographicHash;
class QJsonObject;

// In-app updater for the Linux Flatpak build of !ink.
//
// Checks the repository's latest-build release (its title carries the build
// version, e.g. "Latest Steam Deck build (0.1.0-99685c8)") at start-up and
// every 6 hours. When it differs from this build, update() downloads the
// bundle into the app's cache directory, installs it over this one through the
// host's flatpak (flatpak-spawn --host, which needs the
// --talk-name=org.freedesktop.Flatpak permission), and restarts. In Steam's
// Gaming Mode a self-started process would not be shown, so there it quits and
// asks to be started again from the Library instead.
//
// The downloaded bundle must match the SHA-256 the release lists for it, and
// a check or download that stalls for 30 s fails instead of hanging.
//
// Only active inside the !ink Flatpak; everywhere else it stays idle.
class InkUpdater : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool supported READ supported CONSTANT)
    Q_PROPERTY(bool available READ available NOTIFY changed)
    Q_PROPERTY(QString latestVersion READ latestVersion NOTIFY changed)
    // idle | checking | downloading | installing | restarting | done | error
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(int progress READ progress NOTIFY changed)
    Q_PROPERTY(QString statusText READ statusText NOTIFY changed)

public:
    explicit InkUpdater(QObject* parent = nullptr);
    ~InkUpdater() override;

    bool supported() const { return m_Supported; }
    bool available() const { return m_Available; }
    QString latestVersion() const { return m_LatestVersion; }
    QString state() const { return m_State; }
    int progress() const { return m_Progress; }
    QString statusText() const;

    Q_INVOKABLE void check();
    Q_INVOKABLE void update();
    // Gaming Mode: after installing, quit so Steam can start the new build
    Q_INVOKABLE void quitToFinish();

    // Exposed for tests: the build version in a release title, or empty
    static QString versionFromReleaseTitle(const QString& title);
    // True when the release is a different build than this one
    static bool isNewer(const QString& current, const QString& latest);

    // The bundle's SHA-256 (lowercase hex) from the release JSON, or empty
    static QByteArray bundleSha256FromRelease(const QJsonObject& release);
    // True when the download may be installed
    static bool bundleMatches(const QByteArray& expectedSha256, const QByteArray& actualSha256);

signals:
    void changed();

private:
    void setState(const QString& state, const QString& error = QString());
    void install(const QString& bundlePath);
    void restart();
    static bool inGamingMode();

    QNetworkAccessManager* m_Nam;
    QNetworkReply* m_Download = nullptr;
    QFile* m_DownloadFile = nullptr;
    QScopedPointer<QCryptographicHash> m_DownloadHash;
    QByteArray m_ExpectedSha256;
    bool m_WriteFailed = false;
    bool m_Supported;
    bool m_Available = false;
    QString m_LatestVersion;
    QString m_State = QStringLiteral("idle");
    QString m_Error;
    int m_Progress = 0;
};
