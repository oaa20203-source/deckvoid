#include "inkupdater.h"

#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QTimer>

namespace {
const char* kAppId = "io.github.oaa20203_source.deckvoid";
const char* kReleaseApi = "https://api.github.com/repos/oaa20203-source/deckvoid/releases/tags/latest-build";
const char* kBundleUrl = "https://github.com/oaa20203-source/deckvoid/releases/latest/download/ink-x86_64.flatpak";
const char* kBundleName = "ink-x86_64.flatpak";
// A request with no data for this long has stalled
constexpr int kTransferTimeoutMs = 30 * 1000;
constexpr int kCheckIntervalMs = 6 * 60 * 60 * 1000;
constexpr int kFirstCheckDelayMs = 10 * 1000;
}

InkUpdater::InkUpdater(QObject* parent)
    : QObject(parent),
      m_Nam(new QNetworkAccessManager(this)),
      m_Supported(qEnvironmentVariable("FLATPAK_ID") == QLatin1String(kAppId) &&
                  QFileInfo::exists(QStringLiteral("/.flatpak-info")))
{
    m_Nam->setRedirectPolicy(QNetworkRequest::NoLessSafeRedirectPolicy);
    if (!m_Supported) {
        return;
    }

    QTimer::singleShot(kFirstCheckDelayMs, this, &InkUpdater::check);
    auto* timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &InkUpdater::check);
    timer->start(kCheckIntervalMs);
}

InkUpdater::~InkUpdater() = default;

QString InkUpdater::versionFromReleaseTitle(const QString& title)
{
    // "Latest Steam Deck build (0.1.0-99685c8)" -> "0.1.0-99685c8"
    static const QRegularExpression re(QStringLiteral("\\(([0-9][0-9A-Za-z.\\-]*)\\)\\s*$"));
    const auto match = re.match(title.trimmed());
    return match.hasMatch() ? match.captured(1) : QString();
}

QByteArray InkUpdater::bundleSha256FromRelease(const QJsonObject& release)
{
    // GitHub reports each asset's digest as "sha256:<hex>"
    const auto assets = release.value(QStringLiteral("assets")).toArray();
    for (const auto& value : assets) {
        const auto asset = value.toObject();
        if (asset.value(QStringLiteral("name")).toString() != QLatin1String(kBundleName)) {
            continue;
        }
        const QString digest = asset.value(QStringLiteral("digest")).toString();
        static const QRegularExpression re(QStringLiteral("^sha256:([0-9a-fA-F]{64})$"));
        const auto match = re.match(digest);
        return match.hasMatch() ? match.captured(1).toLower().toLatin1() : QByteArray();
    }
    return QByteArray();
}

bool InkUpdater::isNewer(const QString& current, const QString& latest)
{
    // Builds are identified by version and commit; any different build that the
    // release points at is the newer one, because the release only moves forward.
    return !latest.isEmpty() && !current.isEmpty() && latest != current;
}

QString InkUpdater::statusText() const
{
    if (m_State == QLatin1String("downloading")) {
        return tr("Downloading update… %1%").arg(m_Progress);
    }
    if (m_State == QLatin1String("installing")) {
        return tr("Installing update…");
    }
    if (m_State == QLatin1String("restarting")) {
        return tr("Restarting…");
    }
    if (m_State == QLatin1String("done")) {
        return tr("Updated: quit, then start !ink again →");
    }
    if (m_State == QLatin1String("error")) {
        return tr("Update failed: %1").arg(m_Error);
    }
    if (m_Available) {
        return tr("Update to %1 →").arg(m_LatestVersion);
    }
    return QString();
}

void InkUpdater::setState(const QString& state, const QString& error)
{
    m_State = state;
    m_Error = error;
    emit changed();
}

void InkUpdater::check()
{
    if (!m_Supported || (m_State != QLatin1String("idle") && m_State != QLatin1String("error"))) {
        return;
    }

    QNetworkRequest request{QUrl(QString::fromLatin1(kReleaseApi))};
    request.setRawHeader("Accept", "application/vnd.github+json");
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ink-updater"));
    request.setTransferTimeout(kTransferTimeoutMs);
    QNetworkReply* reply = m_Nam->get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            qInfo() << "Updater: release check failed:" << reply->errorString();
            return;
        }
        const auto release = QJsonDocument::fromJson(reply->readAll()).object();
        const QString latest = versionFromReleaseTitle(release.value(QStringLiteral("name")).toString());
        const QString current = QCoreApplication::applicationVersion();
        m_LatestVersion = latest;
        m_ExpectedSha256 = bundleSha256FromRelease(release);
        m_Available = isNewer(current, latest);
        qInfo() << "Updater: running" << current << "- latest build" << latest
                << (m_Available ? "(update available)" : "(up to date)");
        emit changed();
    });
}

void InkUpdater::update()
{
    if (!m_Supported || m_State == QLatin1String("downloading") || m_State == QLatin1String("installing")) {
        return;
    }
    if (m_State == QLatin1String("done")) {
        quitToFinish();
        return;
    }

    // Cache directory lives under ~/.var/app/<id>/cache, which is the same path
    // on the host, so the host's flatpak can read the bundle we write there.
    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation) + QStringLiteral("/ink-update");
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/ink-x86_64.flatpak");
    QFile::remove(path);

    m_DownloadFile = new QFile(path, this);
    if (!m_DownloadFile->open(QIODevice::WriteOnly)) {
        setState(QStringLiteral("error"), tr("can't write to %1").arg(dir));
        return;
    }

    m_Progress = 0;
    m_WriteFailed = false;
    m_DownloadHash.reset(new QCryptographicHash(QCryptographicHash::Sha256));
    setState(QStringLiteral("downloading"));
    QNetworkRequest request{QUrl(QString::fromLatin1(kBundleUrl))};
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("ink-updater"));
    request.setTransferTimeout(kTransferTimeoutMs);
    m_Download = m_Nam->get(request);
    connect(m_Download, &QNetworkReply::readyRead, this, [this]() {
        const QByteArray chunk = m_Download->readAll();
        m_DownloadHash->addData(chunk);
        if (!m_WriteFailed && m_DownloadFile->write(chunk) != chunk.size()) {
            // Most likely a full disk: stop instead of installing a short file
            m_WriteFailed = true;
            m_Download->abort();
        }
    });
    connect(m_Download, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) {
        if (total > 0) {
            const int pct = int(received * 100 / total);
            if (pct != m_Progress) {
                m_Progress = pct;
                emit changed();
            }
        }
    });
    connect(m_Download, &QNetworkReply::finished, this, [this, path]() {
        m_Download->deleteLater();
        const bool ok = m_Download->error() == QNetworkReply::NoError;
        const QString error = m_Download->errorString();
        m_Download = nullptr;
        const bool flushed = m_DownloadFile->flush();
        m_DownloadFile->close();
        const qint64 size = m_DownloadFile->size();
        m_DownloadFile->deleteLater();
        m_DownloadFile = nullptr;
        const QByteArray sha256 = m_DownloadHash->result().toHex();
        m_DownloadHash.reset();

        if (m_WriteFailed || (ok && !flushed)) {
            QFile::remove(path);
            setState(QStringLiteral("error"), tr("couldn't save the download (is the disk full?)"));
            return;
        }
        // A real bundle is several MB; anything tiny is an error page
        if (!ok || size < 1024 * 1024) {
            QFile::remove(path);
            setState(QStringLiteral("error"), ok ? tr("download was incomplete") : error);
            return;
        }
        if (!bundleMatches(m_ExpectedSha256, sha256)) {
            // Damaged on the way, or a newer build was published since the last
            // check: look again so the next try compares against the right one.
            qWarning() << "Updater: bundle SHA-256" << sha256 << "does not match the release's" << m_ExpectedSha256;
            QFile::remove(path);
            setState(QStringLiteral("error"), tr("the download didn't match the published build; try again"));
            check();
            return;
        }
        if (m_ExpectedSha256.isEmpty()) {
            qWarning() << "Updater: the release lists no SHA-256 for the bundle; installing unverified";
        }
        install(path);
    });
}

bool InkUpdater::bundleMatches(const QByteArray& expectedSha256, const QByteArray& actualSha256)
{
    // A release that lists no digest cannot be checked; one that does must match
    return expectedSha256.isEmpty() || expectedSha256 == actualSha256.toLower();
}

void InkUpdater::install(const QString& bundlePath)
{
    setState(QStringLiteral("installing"));
    auto* proc = new QProcess(this);
    proc->setProcessChannelMode(QProcess::MergedChannels);
    connect(proc, &QProcess::finished, this, [this, proc](int exitCode, QProcess::ExitStatus status) {
        const QString output = QString::fromUtf8(proc->readAll()).trimmed();
        proc->deleteLater();
        if (status != QProcess::NormalExit || exitCode != 0) {
            qWarning() << "Updater: install failed:" << output;
            setState(QStringLiteral("error"), output.isEmpty() ? tr("flatpak exited with %1").arg(exitCode)
                                                              : output.section(QLatin1Char('\n'), -1));
            return;
        }
        qInfo() << "Updater: installed" << m_LatestVersion;
        m_Available = false;
        if (inGamingMode()) {
            setState(QStringLiteral("done"));
        }
        else {
            restart();
        }
    });
    proc->start(QStringLiteral("flatpak-spawn"),
                {QStringLiteral("--host"), QStringLiteral("flatpak"), QStringLiteral("install"),
                 QStringLiteral("--user"), QStringLiteral("--noninteractive"), QStringLiteral("-y"),
                 QStringLiteral("--reinstall"), bundlePath});
}

bool InkUpdater::inGamingMode()
{
    return qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains(QLatin1String("gamescope"), Qt::CaseInsensitive) ||
           qEnvironmentVariableIsSet("SteamGamepadUI") || qEnvironmentVariableIsSet("GAMESCOPE_WAYLAND_DISPLAY");
}

void InkUpdater::restart()
{
    setState(QStringLiteral("restarting"));
    // Start the new build on the host after this one has exited
    QProcess::startDetached(QStringLiteral("flatpak-spawn"),
                            {QStringLiteral("--host"), QStringLiteral("sh"), QStringLiteral("-c"),
                             QStringLiteral("sleep 1; exec flatpak run %1").arg(QLatin1String(kAppId))});
    QTimer::singleShot(300, qApp, &QCoreApplication::quit);
}

void InkUpdater::quitToFinish()
{
    QCoreApplication::quit();
}
