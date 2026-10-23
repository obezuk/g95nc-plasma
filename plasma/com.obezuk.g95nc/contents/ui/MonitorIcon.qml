import QtQuick
import org.kde.kirigami as Kirigami

// Paint with the panel's foreground directly; no SVG tinting or shader is needed.
Canvas {
    property color ink: Kirigami.Theme.textColor
    implicitWidth: 32
    implicitHeight: 32
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const c = getContext('2d');
        c.reset();
        c.scale(width / 32, height / 32);
        c.strokeStyle = ink;
        c.lineWidth = 2;
        c.lineCap = 'round';
        c.lineJoin = 'round';
        c.beginPath();
        c.moveTo(3, 6); c.quadraticCurveTo(16, 10, 29, 6);
        c.lineTo(29, 22); c.quadraticCurveTo(16, 18, 3, 22);
        c.closePath(); c.stroke();
        c.beginPath();
        c.moveTo(16, 8); c.lineTo(16, 26);
        c.moveTo(10, 27); c.quadraticCurveTo(16, 25, 22, 27);
        c.stroke();
    }
}
