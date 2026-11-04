#pragma once

#include "apollohostinfo.h"
#include "apollopermissions.h"

#include <QString>
#include <QVector>

// In-stream quick menu v0: which items exist for this host, the selection, and
// the text the overlay draws. Pure logic; Session handles input and actions.
class ApolloQuickMenu
{
public:
    enum Kind { ServerCommand, PushClipboard, PullClipboard, ToggleStats, Disconnect, QuitApp };

    struct Item {
        Kind kind;
        int commandIndex; // ServerCommand only: index into the host's ServerCommand list
        QString label;
    };

    // Items for this host. Missing permissions hide items rather than disable them.
    void build(bool isApollo, const ApolloHostInfo& host, bool clipboardSyncOn)
    {
        m_Items.clear();
        const bool known = isApollo && host.permissionsKnown;
        const auto has = [&](uint32_t bit) { return known && ApolloPermissions::has(host.permissions, bit); };

        if (has(ApolloPermissions::ServerCommand)) {
            for (int i = 0; i < host.serverCommands.size() && i < 256; i++) {
                QString name = host.serverCommands[i].trimmed();
                if (name.isEmpty()) {
                    continue; // keeps its index, but there is nothing to show
                }
                if (name.size() > kMaxCommandName) {
                    name = name.left(kMaxCommandName - 3) + "...";
                }
                m_Items.append({ServerCommand, i, QStringLiteral("Server command: ") + name});
            }
        }
        if (clipboardSyncOn && has(ApolloPermissions::ClipboardSet)) {
            m_Items.append({PushClipboard, -1, QStringLiteral("Push clipboard to PC")});
        }
        if (clipboardSyncOn && has(ApolloPermissions::ClipboardRead)) {
            m_Items.append({PullClipboard, -1, QStringLiteral("Pull clipboard from PC")});
        }
        m_Items.append({ToggleStats, -1, QStringLiteral("Toggle stats")});
        m_Items.append({Disconnect, -1, QStringLiteral("Disconnect")});
        // Stock hosts let any paired client quit; Apollo needs the launch permission.
        if (!isApollo || !host.permissionsKnown || has(ApolloPermissions::Launch)) {
            m_Items.append({QuitApp, -1, QStringLiteral("Quit app on PC")});
        }
        m_Selected = 0;
    }

    bool isOpen() const { return m_Open; }
    void open() { m_Open = true; m_Selected = 0; }
    void close() { m_Open = false; }

    void moveUp() { if (!m_Items.isEmpty()) m_Selected = (m_Selected + m_Items.size() - 1) % m_Items.size(); }
    void moveDown() { if (!m_Items.isEmpty()) m_Selected = (m_Selected + 1) % m_Items.size(); }

    const QVector<Item>& items() const { return m_Items; }
    int selectedIndex() const { return m_Selected; }
    const Item* selected() const { return m_Items.isEmpty() ? nullptr : &m_Items[m_Selected]; }

    // Overlay text: one line per item, "> " marks the selection. Fits the
    // overlay's 1024-byte buffer; trailing items are dropped if needed.
    QByteArray text() const
    {
        QByteArray out = "DeckVoid menu   (A/Enter select, B/Esc close)\n\n";
        for (int i = 0; i < m_Items.size(); i++) {
            const QByteArray line = (i == m_Selected ? "> " : "   ") + m_Items[i].label.toUtf8() + "\n";
            if (out.size() + line.size() > kMaxText) {
                break;
            }
            out += line;
        }
        return out;
    }

    static constexpr int kMaxText = 1023;
    static constexpr int kMaxCommandName = 40;

private:
    QVector<Item> m_Items;
    int m_Selected = 0;
    bool m_Open = false;
};
