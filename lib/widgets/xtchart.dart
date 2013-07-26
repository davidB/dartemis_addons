// License [CC0](http://creativecommons.org/publicdomain/zero/1.0/)

import 'dart:html';
import 'dart:math';
import 'package:web_ui/web_ui.dart';


/**
 * A simple widget to chart sequence(s) of number like a time-serie.
 *
 * Inspiration from :
 * * [Cubism.js](http://square.github.io/cubism/)
 * * [Smoothie Charts](http://smoothiecharts.org/)
 * * [50 JavaScript Libraries for Charts and Graphs](http://techslides.com/50-javascript-charting-and-graphics-libraries/)
 */
class XTchart extends WebComponent{
  /// minimal value to display on y axis (clamp), default : 0.0
  var ymin = 0.0;
  /// maximal value to display on y axis (clamp), default : 100.0
  var ymax = 100.0;
//  var _offScreen = null;
//  var _offImage = null;
  var _onScreen = null;

  /// should graph displayed as stacked or on its own line
  var stack = false;

  /// the defaults 7 colors use to display values, change the content to change or to add colors
  var colors = ['rgb(153, 216, 201)', 'rgb(158, 188, 218)', 'rgb(253, 187, 132)', 'rgb(201, 148, 199)', 'rgb(188, 189, 220)', 'rgb(161, 217, 155)', 'rgb(189, 189, 189)'];

  clamp0(high, value) => max(0, min(high, value));

  /// Forward of one step (1 pixel) and chart [values] as value for the values.length serie.
  /// If values or values[x] is null the value is ignore (~ [ymin]) and chart go one step.
  /// If [push] is not called then the chart is not modified.
  ///
  //TODO bench full redraw (need to keep all visible data) vs shift left (by canvas copy)
  //see http://stackoverflow.com/questions/8376534/shift-canvas-contents-to-the-left
  //TODO optim canvas copy by create chunck of images and keep imageData between pull
  push(List values) {
    var c = _onScreen;
    var g = c.context2d;
    var x0 = 0.5;
    var y0 = 0.5;
    var w0 = c.width;
    var h0 = c.height;
    g.save();
    shiftContext(g, w0, h0, -1, 0);
    if (values != null) {
      var l = values.length;
      var hi = h0 / l;
      var yratio = hi/(ymax - ymin);
      var x = x0+w0 - 1;
      var y = y0+h0 - 1;
      var h = 0;
      for (var i = l - 1; i > -1; i--) {
        var v = values[i];
        if (v == null) v = ymin;
        g.beginPath();
        h = clamp0(ymax, (v - ymin)) * yratio;
        g.moveTo(x, y - h);
        g.lineTo(x, y);
        g.closePath();
//      var gradient = g.createLinearGradient(0, h0+y, 0, y);
//      gradient.addColorStop(0, 'rgb(129, 15, 124)');
//      gradient.addColorStop(1, 'rgb(191, 211, 230)');
//      g.strokeStyle = gradient;
        g.strokeStyle = colors[i % colors.length];
        g.stroke();
        y = (stack)? y - h : y - hi;
      }
      g.restore();
    }
//    var imageData = g.getImageData(0, 0, w0, h0);
//    _offImage = imageData;
//    window.animationFrame.then((_){
//      var g = _onScreen.context2d;
//      //g.clearRect(0, 0, _onScreen.width, _onScreen.height);
//      //g.drawImage(_offScreen, 0, 0);
//      g.putImageData(_offImage, 0, 0);
//    });
  }

  shiftContext(g, w, h, dx, dy) {
    var imageData = g.getImageData(clamp0(w, -dx), clamp0(h, -dy), clamp0(w, w-dx), clamp0(h, h-dy));
    g.putImageData(imageData, 0, 0);
    g.clearRect(w-1, 0, 1, h);
  }

  void inserted() {
    _onScreen = this.query('canvas') as CanvasElement;
  }
}
