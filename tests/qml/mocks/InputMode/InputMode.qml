pragma Singleton
import QtQuick

// Test stand-in for the C++ InputMode singleton that Theme.qml reads.
QtObject {
    property string mode: "controller"
}
