import QtQuick

// The centered sign-in form shared by the login screen and the lock screen:
// avatar, name, a status line, the password box and a message line.
Column {
  id: form

  property FormStyle st
  property string displayName: ""
  property string userName: ""
  property string picture: ""          // avatar file url
  property string faceIcon: ""
  property string status: ""           // e.g. "Locked", "Signed in"
  property string statusGlyph: ""
  property string message: ""          // under the box: hints and notices
  property bool messageIsError: false

  readonly property alias passwordBox: passwordBox

  spacing: 0

  UserAvatar {
    anchors.horizontalCenter: parent.horizontalCenter
    width: 128 * form.st.ui
    height: width
    ringWidth: 3 * form.st.ui
    picture: form.picture
    faceIcon: form.faceIcon
    label: form.displayName || form.userName
    accent: form.st.accent
    ink: form.st.back
    ring: form.st.alpha(form.st.bright, 0.9)
    fontFamily: form.st.fontFamily
  }

  Item { width: 1; height: 18 * form.st.ui }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    text: form.displayName || form.userName
    textFormat: Text.PlainText
    color: form.st.bright
    font.family: form.st.fontFamily
    font.pixelSize: 28 * form.st.ui
    font.bold: true
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: !!form.displayName && form.displayName !== form.userName && !!form.userName
    text: form.userName
    textFormat: Text.PlainText
    color: form.st.text
    font.family: form.st.fontFamily
    font.pixelSize: 14 * form.st.ui
    topPadding: 2 * form.st.ui
  }
  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    visible: form.status !== ""
    text: (form.statusGlyph ? form.statusGlyph + "  " : "") + form.status
    textFormat: Text.PlainText
    color: form.st.accent
    font.family: form.st.fontFamily
    font.pixelSize: 14 * form.st.ui
    topPadding: 6 * form.st.ui
  }

  Item { width: 1; height: 24 * form.st.ui }

  PasswordBox {
    id: passwordBox
    anchors.horizontalCenter: parent.horizontalCenter
    st: form.st
  }

  Text {
    anchors.horizontalCenter: parent.horizontalCenter
    width: passwordBox.width
    horizontalAlignment: Text.AlignHCenter
    wrapMode: Text.Wrap
    visible: form.message !== ""
    text: form.message
    textFormat: Text.PlainText
    color: form.messageIsError ? form.st.error : form.st.text
    font.family: form.st.fontFamily
    font.pixelSize: 13 * form.st.ui
    topPadding: 14 * form.st.ui
  }
}
