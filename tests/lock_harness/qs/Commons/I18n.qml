pragma Singleton
import QtQuick
QtObject {
  readonly property bool rightToLeft: false
  function t(key) { return ({ "lock.enterPassword": "Enter Password", "lock.checking": "Checking…",
                              "lock.fingerprintUnavailable": "Fingerprint reader unavailable" })[key] || key }
}
