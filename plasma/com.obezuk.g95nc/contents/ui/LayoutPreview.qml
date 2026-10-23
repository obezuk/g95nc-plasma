import QtQuick

Canvas {
    id: canvas
    EditorColors { id: colors }
    property var widths: [100]
    property var sources: []
    onSourcesChanged: requestPaint()
    property bool pip: false
    property bool miniature: height < 32
    property bool selected: false
    property int highlightedPane: -1
    implicitWidth: 320
    implicitHeight: implicitWidth * 9 / 32
    onWidthsChanged: requestPaint()
    onPipChanged: requestPaint()
    onSelectedChanged: requestPaint()
    onHighlightedPaneChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Connections { target: colors; function onDarkChanged() { canvas.requestPaint(); } }
    onPaint: {
        const c = getContext('2d'); c.reset();
        const w = width - 2, h = height - 2;
        if (w <= 0 || h <= 0) return;
        c.translate(1,1);
        c.beginPath();
        c.moveTo(w * .012, h * .005);
        c.quadraticCurveTo(w * .5, h * .235, w * .988, h * .005);
        c.quadraticCurveTo(w, 0, w, h * .018);
        c.lineTo(w, h * .982);
        c.quadraticCurveTo(w, h, w * .988, h * .995);
        c.quadraticCurveTo(w * .5, h * .765, w * .012, h * .995);
        c.quadraticCurveTo(0, h, 0, h * .982);
        c.lineTo(0, h * .018);
        c.quadraticCurveTo(0, 0, w * .012, h * .005);
        c.closePath(); c.save(); c.clip();
        let offset = 0;
        const panes = pip ? [100] : widths;
        panes.forEach(function(percent, index) {
            const span = percent * w / 100;
            if (miniature) c.fillStyle = selected ? colors.secondary : colors.outline;
            else if (sources[index]) c.fillStyle = colors.inputFill(sources[index], highlightedPane === index);
            else if (highlightedPane === index) c.fillStyle = colors.paneSelected;
            else {
                const gradient = c.createLinearGradient(0, 0, 0, h);
                gradient.addColorStop(0, index % 2 ? colors.paneAltTop : colors.paneTop);
                gradient.addColorStop(1, index % 2 ? colors.paneAltBottom : colors.paneBottom);
                c.fillStyle = gradient;
            }
            c.fillRect(offset, 0, span, h);
            if (index) { c.strokeStyle = miniature ? colors.surface : colors.outline; c.lineWidth = 1; c.beginPath(); c.moveTo(offset,0); c.lineTo(offset,h); c.stroke(); }
            offset += span;
        });
        if (pip) {
            c.fillStyle = sources[1] ? colors.inputFill(sources[1], highlightedPane === 1) : highlightedPane === 1 ? colors.paneSelected : colors.surface;
            c.fillRect(w * .7, h * .56, w * .25, h * .3);
            c.strokeStyle = colors.outline; c.lineWidth = 1;
            c.strokeRect(w * .7, h * .56, w * .25, h * .3);
        }
        c.restore();
        // Recreate the silhouette after drawing internal paths.
        c.beginPath(); c.moveTo(0,0); c.quadraticCurveTo(w/2,h*.23,w,0);
        c.lineTo(w,h); c.quadraticCurveTo(w/2,h*.77,0,h); c.closePath();
        c.strokeStyle = miniature ? 'transparent' : colors.outline; c.lineWidth = 1; c.stroke();
    }
}
