#pragma once

#include <QString>
#include <QStringList>
#include <QXmlStreamReader>
#include <cstdint>

// Apollo-family (/serverinfo) extensions, as sent by Apollo and Vibepollo
// (Vibepollo 2.0.6 src/nvhttp.cpp:4216-4446). Neither host sends a version
// tag that identifies it, so "detected" means the Apollo-only virtual display
// or permission tags are present. Stock Sunshine and GeForce hosts send neither.
struct ApolloHostInfo
{
    bool detected = false;

    // <Permission> is only meaningful on a paired HTTPS response; over plain
    // HTTP the host always reports 0.
    bool permissionsKnown = false;
    uint32_t permissions = 0;

    // Names in host order. The index in this list is what packet 0x3000 carries,
    // so entries are never filtered or reordered (an empty name keeps its slot).
    QStringList serverCommands;

    bool virtualDisplayCapable = false;
    bool virtualDisplayDriverReady = false;
    bool virtualDisplayHdrCapable = false;

    // UUID of the app this client is running on the host, empty if none.
    QString currentGameUuid;

    bool operator==(const ApolloHostInfo& other) const
    {
        return detected == other.detected &&
               permissionsKnown == other.permissionsKnown &&
               permissions == other.permissions &&
               serverCommands == other.serverCommands &&
               virtualDisplayCapable == other.virtualDisplayCapable &&
               virtualDisplayDriverReady == other.virtualDisplayDriverReady &&
               virtualDisplayHdrCapable == other.virtualDisplayHdrCapable &&
               currentGameUuid == other.currentGameUuid;
    }
    bool operator!=(const ApolloHostInfo& other) const { return !(*this == other); }

    static ApolloHostInfo fromServerInfo(const QString& serverInfo)
    {
        ApolloHostInfo result;
        bool sawPermission = false;
        bool paired = false;

        QXmlStreamReader xml(serverInfo);
        while (!xml.atEnd()) {
            if (xml.readNext() != QXmlStreamReader::StartElement) continue;
            const auto name = xml.name();
            if (name == QLatin1String("VirtualDisplayCapable")) {
                result.detected = true;
                result.virtualDisplayCapable = isTrue(xml.readElementText());
            }
            else if (name == QLatin1String("VirtualDisplayDriverReady")) {
                result.detected = true;
                result.virtualDisplayDriverReady = isTrue(xml.readElementText());
            }
            else if (name == QLatin1String("VirtualDisplayHDRCapable")) {
                result.detected = true;
                result.virtualDisplayHdrCapable = isTrue(xml.readElementText());
            }
            else if (name == QLatin1String("Permission")) {
                result.detected = true;
                sawPermission = true;
                result.permissions = xml.readElementText().trimmed().toUInt();
            }
            else if (name == QLatin1String("ServerCommand")) {
                result.serverCommands << xml.readElementText();
            }
            else if (name == QLatin1String("currentgameuuid")) {
                result.currentGameUuid = xml.readElementText().trimmed();
            }
            else if (name == QLatin1String("PairStatus")) {
                paired = xml.readElementText().trimmed() == QLatin1String("1");
            }
        }

        if (xml.hasError()) {
            return ApolloHostInfo{};
        }

        result.permissionsKnown = sawPermission && paired;
        return result;
    }

private:
    static bool isTrue(const QString& value)
    {
        const auto trimmed = value.trimmed();
        return trimmed == QLatin1String("1") || trimmed.compare(QLatin1String("true"), Qt::CaseInsensitive) == 0;
    }
};
