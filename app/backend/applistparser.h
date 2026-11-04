#pragma once

#include "nvapp.h"

#include <QDebug>
#include <QVector>
#include <QXmlStreamReader>

#include <algorithm>
#include <stdexcept>

// /applist parsing and ordering, kept free of networking so it can be tested.
// Apollo-family hosts add UUID, IDX and ArtVersion to each <App>
// (Vibepollo 2.0.6 src/nvhttp.cpp:4745-4758).
namespace AppListParser {

inline QVector<NvApp> parse(const QString& appxml)
{
    QXmlStreamReader xmlReader(appxml);
    QVector<NvApp> apps;
    while (!xmlReader.atEnd()) {
        while (xmlReader.readNextStartElement()) {
            const auto name = xmlReader.name();
            if (name == QLatin1String("App")) {
                // We must have a valid app before advancing to the next one
                if (!apps.isEmpty() && !apps.last().isInitialized()) {
                    qWarning() << "Invalid applist XML";
                    throw std::runtime_error("Invalid applist XML");
                }
                apps.append(NvApp());
            }
            else if (!apps.isEmpty()) {
                if (name == QLatin1String("AppTitle")) {
                    // If an app has no name, Sunshine may send us <AppTitle/>,
                    // which readElementText() returns as a null QString.
                    // We want to treat this as an empty QString instead, so we
                    // will explicitly convert it. An empty string will satisfy
                    // NvApp's isInitialized() check.
                    QString title = xmlReader.readElementText();
                    if (title.isNull()) {
                        title = "";
                    }
                    apps.last().name = title;
                }
                else if (name == QLatin1String("ID")) {
                    apps.last().id = xmlReader.readElementText().toInt();
                }
                else if (name == QLatin1String("IsHdrSupported")) {
                    apps.last().hdrSupported = xmlReader.readElementText() == "1";
                }
                else if (name == QLatin1String("IsAppCollectorGame")) {
                    apps.last().isAppCollectorGame = xmlReader.readElementText() == "1";
                }
                else if (name == QLatin1String("UUID")) {
                    apps.last().uuid = xmlReader.readElementText().trimmed();
                }
                else if (name == QLatin1String("IDX")) {
                    // IDX is a string. Configured apps carry their 0-based position;
                    // control tiles carry their (large) ID; catalogue entries may
                    // leave it empty. Anything not a non-negative integer is unnumbered.
                    bool ok = false;
                    const qint64 value = xmlReader.readElementText().trimmed().toUInt(&ok);
                    apps.last().hostIndex = ok ? value : -1;
                }
                else if (name == QLatin1String("ArtVersion")) {
                    apps.last().artVersion = xmlReader.readElementText().trimmed();
                }
            }
        }
    }

    return apps;
}

// Host order when the host numbered its apps (IDX), name order otherwise.
// Unnumbered apps follow numbered ones; ties keep the host's XML order.
inline void sort(QVector<NvApp>& apps)
{
    const bool hostOrdered = std::any_of(apps.cbegin(), apps.cend(),
                                         [](const NvApp& app) { return app.hostIndex >= 0; });
    if (hostOrdered) {
        std::stable_sort(apps.begin(), apps.end(), [](const NvApp& a, const NvApp& b) {
            if ((a.hostIndex < 0) != (b.hostIndex < 0)) {
                return a.hostIndex >= 0;
            }
            return a.hostIndex >= 0 && a.hostIndex < b.hostIndex;
        });
    }
    else {
        std::stable_sort(apps.begin(), apps.end(), [](const NvApp& a, const NvApp& b) {
            return a.name.toLower() < b.name.toLower();
        });
    }
}

} // namespace AppListParser
