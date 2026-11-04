#pragma once

#include <QCoreApplication>
#include <QStringList>
#include <cstdint>

// Per-client permission bits reported by Apollo-family hosts in /serverinfo
// (<Permission>, decimal). Values from Apollo's crypto::PERM, unchanged in
// Vibepollo 2.0.6 (src/crypto.h:48-77). New clients default to View | List.
namespace ApolloPermissions {

enum Bit : uint32_t {
    InputController = 0x00000100,
    InputTouch      = 0x00000200,
    InputPen        = 0x00000400,
    InputMouse      = 0x00000800,
    InputKeyboard   = 0x00001000,
    ClipboardSet    = 0x00010000,
    ClipboardRead   = 0x00020000,
    FileUpload      = 0x00040000,
    FileDownload    = 0x00080000,
    ServerCommand   = 0x00100000,
    List            = 0x01000000,
    View            = 0x02000000,
    Launch          = 0x04000000, // also covers quitting the running app
};

inline bool has(uint32_t permissions, uint32_t bit)
{
    return (permissions & bit) == bit;
}

// Human-readable names of the granted bits, lowest bit first. Unknown bits are skipped.
inline QStringList names(uint32_t permissions)
{
    static const struct { uint32_t bit; const char* name; } kNames[] = {
        { InputController, QT_TRANSLATE_NOOP("ApolloPermissions", "Controller input") },
        { InputTouch,      QT_TRANSLATE_NOOP("ApolloPermissions", "Touch input") },
        { InputPen,        QT_TRANSLATE_NOOP("ApolloPermissions", "Pen input") },
        { InputMouse,      QT_TRANSLATE_NOOP("ApolloPermissions", "Mouse input") },
        { InputKeyboard,   QT_TRANSLATE_NOOP("ApolloPermissions", "Keyboard input") },
        { ClipboardSet,    QT_TRANSLATE_NOOP("ApolloPermissions", "Set clipboard") },
        { ClipboardRead,   QT_TRANSLATE_NOOP("ApolloPermissions", "Read clipboard") },
        { FileUpload,      QT_TRANSLATE_NOOP("ApolloPermissions", "Upload files") },
        { FileDownload,    QT_TRANSLATE_NOOP("ApolloPermissions", "Download files") },
        { ServerCommand,   QT_TRANSLATE_NOOP("ApolloPermissions", "Run server commands") },
        { List,            QT_TRANSLATE_NOOP("ApolloPermissions", "List applications") },
        { View,            QT_TRANSLATE_NOOP("ApolloPermissions", "View streams") },
        { Launch,          QT_TRANSLATE_NOOP("ApolloPermissions", "Launch applications") },
    };
    QStringList result;
    for (const auto& entry : kNames) {
        if (has(permissions, entry.bit)) {
            result << QCoreApplication::translate("ApolloPermissions", entry.name);
        }
    }
    return result;
}

} // namespace ApolloPermissions
