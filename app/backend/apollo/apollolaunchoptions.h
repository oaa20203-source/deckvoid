#pragma once

#include <QString>
#include <QUrl>

#include <algorithm>

// Extra /launch and /resume query parameters for Apollo-family hosts
// (Vibepollo 2.0.6 src/nvhttp.cpp:3053-3493). Stock hosts get none of them.
struct ApolloLaunchOptions
{
    bool apolloHost = false;

    QString appUuid;          // resolves the app before the numeric ID (:3288-3297)
    int virtualDisplay = -1;  // -1 host decides (omitted), 0 physical, 1 virtual (:3302-3307)
    int scaleFactor = 100;    // percent of the requested mode for the host's virtual display (:3422-3465)
    QString clientName;       // used only if the paired record has no name (:3102-3109)

    QString queryString() const
    {
        if (!apolloHost) {
            return QString();
        }

        QString query;
        if (!appUuid.isEmpty()) {
            query += "&appuuid=" + encode(appUuid);
        }
        if (virtualDisplay == 0 || virtualDisplay == 1) {
            query += "&virtualDisplay=" + QString::number(virtualDisplay);
        }
        const int scale = std::clamp(scaleFactor, 20, 200);
        if (scale != 100) {
            query += "&scaleFactor=" + QString::number(scale);
        }
        const QString name = clientName.trimmed();
        // The host refuses a client named "self" (src/nvhttp.cpp:2906-2909).
        if (!name.isEmpty() && name.compare(QLatin1String("self"), Qt::CaseInsensitive) != 0) {
            query += "&clientName=" + encode(name);
        }
        return query;
    }

private:
    static QString encode(const QString& value)
    {
        return QString::fromLatin1(QUrl::toPercentEncoding(value));
    }
};

// How to present a non-200 launch/resume status from an Apollo-family host.
namespace ApolloLaunchReply {

enum class Kind {
    Error,          // show the host's status_message as a failure
    Notice,         // 410: not an error; show the message, start no stream
    RetryAsLaunch,  // 503 on /resume: the app exited since the last poll
};

inline Kind classify(int statusCode, bool wasResume)
{
    if (statusCode == 410) {
        return Kind::Notice;
    }
    if (statusCode == 503 && wasResume) {
        return Kind::RetryAsLaunch;
    }
    return Kind::Error;
}

} // namespace ApolloLaunchReply
