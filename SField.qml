import QtQuick

// A one-line text field in the dashboard's style. `secret` hides what's typed
// (for passwords and keys); nothing typed is ever logged or saved by this.
Rectangle {
  id: f

  property var t
  property alias text: input.text
  property string placeholder: ""
  property string accessibleName: ""
  property bool secret: false
  property int maxLength: 200
  signal submitted(string text)
  signal accepted()

  width: t.px(240)
  height: t.px(32)
  radius: t.radiusSmall
  color: t.glassInset
  border.width: 1
  border.color: input.activeFocus ? t.accent : t.border
  InsetShade { t: f.t }

  function clear() { input.text = "" }
  function focusInput() { input.forceActiveFocus() }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: f.t.px(10)
    anchors.rightMargin: f.t.px(10)
    verticalAlignment: TextInput.AlignVCenter
    color: f.t.text
    font.family: f.t.font
    font.pixelSize: f.t.px(12.5)
    selectionColor: f.t.alpha(f.t.accent, 0.35)
    echoMode: f.secret ? TextInput.Password : TextInput.Normal
    passwordCharacter: "•"
    inputMethodHints: f.secret ? Qt.ImhSensitiveData | Qt.ImhNoPredictiveText : Qt.ImhNone
    clip: true
    maximumLength: f.maxLength
    activeFocusOnTab: true
    Accessible.role: Accessible.EditableText
    Accessible.name: f.accessibleName
    Accessible.passwordEdit: f.secret
    onEditingFinished: f.submitted(text)
    Keys.onReturnPressed: f.accepted()
    Keys.onEnterPressed: f.accepted()
    JText {
      anchors.fill: parent
      visible: !input.text.length
      t: f.t
      text: f.placeholder
      size: 12.5
      color: f.t.textFaint
    }
  }
}
