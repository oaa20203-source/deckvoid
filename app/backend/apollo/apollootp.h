#pragma once

#include <QByteArray>
#include <QCryptographicHash>
#include <QRegularExpression>
#include <QString>
#include <QUrl>

// One-time-PIN pairing for Apollo-family hosts (Vibepollo 2.0.6 src/nvhttp.cpp:4054-4082).
// The host owner creates a 4-digit PIN with a passphrase on the host; the client adds
// otpauth to its first pairing request and otherwise pairs exactly as usual.
namespace ApolloOtp {

// Uppercase hex of SHA-256(pin + saltHex + passphrase); saltHex is the exact
// salt= string sent in the same getservercert request.
inline QByteArray otpAuth(const QString& pin, const QByteArray& saltHex, const QString& passphrase)
{
    QByteArray input = pin.toUtf8();
    input.append(saltHex);
    input.append(passphrase.toUtf8());
    return QCryptographicHash::hash(input, QCryptographicHash::Sha256).toHex().toUpper();
}

inline bool isValidPin(const QString& pin)
{
    static const QRegularExpression fourDigits(QStringLiteral("^[0-9]{4}$"));
    return fourDigits.match(pin).hasMatch();
}

inline bool isValidPassphrase(const QString& passphrase)
{
    return passphrase.size() >= 4;
}

// devicename= value for pairing requests. Apollo shows it in its device list;
// "roth" is what stock Moonlight sends. The host refuses "self" (:2906-2909).
inline QString deviceNameArg(const QString& clientName)
{
    const QString name = clientName.trimmed();
    if (name.isEmpty() || name.compare(QLatin1String("self"), Qt::CaseInsensitive) == 0) {
        return QStringLiteral("roth");
    }
    return QString::fromLatin1(QUrl::toPercentEncoding(name));
}

} // namespace ApolloOtp
