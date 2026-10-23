import QtQuick
import org.kde.kirigami as Kirigami
Canvas {
    property string source
    property color ink: Kirigami.Theme.textColor
    implicitWidth: 24
    implicitHeight: 20
    onSourceChanged: requestPaint()
    onInkChanged: requestPaint()
    onPaint: {
        const c = getContext('2d'); c.reset(); c.scale(width / 28, height / 22);
        c.strokeStyle = ink; c.lineWidth = 1.5; c.lineJoin = 'round'; c.beginPath();
        if (source === 'DisplayPort') { c.moveTo(4,4); c.lineTo(20,4); c.lineTo(24,8); c.lineTo(24,18); c.lineTo(4,18); }
        else { c.moveTo(3,6); c.lineTo(25,6); c.lineTo(22,17); c.lineTo(6,17); }
        c.closePath(); c.stroke(); c.beginPath();
        c.moveTo(8,10); c.lineTo(20,10); c.moveTo(9,13); c.lineTo(19,13); c.stroke();
    }
}
