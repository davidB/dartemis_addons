// License [CC0](http://creativecommons.org/publicdomain/zero/1.0/)

/// Use to debug or to prototype display in canvas
/// use it with prefix
///
///    import 'package:dartemis_toolbox/system_proto2d.dart' as proto;
///
/// It's an unoptimize library (ex : failed 100% of the advices at
/// [Optimizing canvas - MDN](https://developer.mozilla.org/en-US/docs/HTML/Canvas/Tutorial/Optimizing_canvas)
///
/// the library include primitive DrawCanvas function (pseudo "function curring")

library system_proto2d;

import 'dart:html';
import 'dart:math' as math;
import 'package:dartemis/dartemis.dart';
import 'package:vector_math/vector_math.dart';
import 'system_transform.dart';
import 'system_particles.dart';
import 'colors.dart';

typedef void DrawCanvas(CanvasRenderingContext2D g, Entity e, Vector2 area);

class Drawable extends Component {
  DrawCanvas draw = null;

  Drawable(this.draw);
}

class DrawComponentType {
  final ComponentType ct;
  final DrawCanvas draw;
  DrawComponentType(this.ct, this.draw);
}

DrawCanvas drawComponentType(List<DrawComponentType> l) => (CanvasRenderingContext2D g, Entity e, area) {
  l.forEach((i) {
    if (e.getComponent(i.ct) != null) {
      i.draw(g, e, area);
    }
  });
};

class System_Renderer extends EntityProcessingSystem {
  final CanvasRenderingContext2D _gVisible;
  final CanvasRenderingContext2D _g;
  ComponentMapper<Transform> _transformMapper;
  ComponentMapper<Drawable> _drawMapper;
  var _w = 0;
  var _h = 0;
  var _dpr = 1.0;
  /// [_areaEntity] temp variable use fill by [Drawable.draw] to give the modified
  /// area, it is an area with center at (0.0, 0.0)
  Vector2 _areaEntity = new Vector2(0.0, 0.0);
  /// _areaEntities sum of the _areaEntity in original state.
  /// TODO optim : use _areaEntity and _areaEntities to clear and to update offscreen canvas
  //vec4 _areaEntities = new vec4(0.0, 0.0);

  var translateX = 0.0;
  var translateY = 0.0;

  var _scale = 1.0;
  var _scaleI = 1.0;
  get scale => _scale / _dpr;
  set scale(v) {
    _scale = v * _dpr;
    _scaleI = 1 / _scale;
  }


  System_Renderer(canvas) :
    super(Aspect.getAspectForAllOf([Drawable])),
    _gVisible = canvas.context2D,
    _g = new CanvasElement().context2D
    ;

  void initialize(){
    _drawMapper = new ComponentMapper<Drawable>(Drawable, world);
    _transformMapper = new ComponentMapper<Transform>(Transform, world);
    _initCanvasDimension();
    if (printCanvas == null) {
      printCanvas = _g;
    }
  }

  void _initCanvasDimension() {
    // to avoid scale and blur
    // canvas dimensions
    var canvasV = _gVisible.canvas;
    var s = scale;
    _dpr = window.devicePixelRatio;     // retina
    scale = s;

    _w = (_dpr * canvasV.clientWidth).round();//parseInt(canvas.style.width);
    _h = (_dpr * canvasV.clientHeight).round(); //parseInt(canvas.style.height);

    canvasV.width = _w;
    canvasV.height = _h;
    _gVisible.scale(_dpr, _dpr);
    _g.canvas.width = _w;
    _g.canvas.height = _h;

  }

  void begin() {
    //TODO use a viewport (translation, rotation, scale);
    _g.save();
  }

  void processEntity(Entity entity) {
    _g.translate(translateX, translateY);
    if (_scale != 1.0) _g.scale(_scale, _scale);

    var d = _drawMapper.get(entity);
    var tf = _transformMapper.getSafe(entity);
    if (tf != null) {
      _g.translate(tf.position3d.x.toInt(), tf.position3d.y.toInt());
      _g.rotate(tf.rotation3d.z);
      _g.scale(tf.scale3d.x, tf.scale3d.y);
    }
    _areaEntity.x = 0.0;
    _areaEntity.y = 0.0;
    d.draw(_g, entity, _areaEntity);
    if (tf != null) {
      _g.scale(1/tf.scale3d.x, 1/tf.scale3d.y);
      _g.rotate(-tf.rotation3d.z);
      _g.translate(-tf.position3d.x.toInt(), -tf.position3d.y.toInt());
    }

    if (_scale != 1.0) _g.scale(_scaleI, _scaleI);
    _g.translate(- translateX, - translateY);
    _g.restore();
  }

  void end() {
    _g.restore();
    _gVisible.clearRect(0, 0, _w, _h);
    _gVisible.drawImage(_g.canvas, 0, 0);
    _g.clearRect(0, 0, _w, _h);
  }
}

DrawCanvas rect(w, h, {fillStyle, strokeStyle, strokeLineWidth : 1, strokeLineDashOffset : 0}) => (CanvasRenderingContext2D g, Entity e, area) {
  if (strokeStyle == null && fillStyle == null) return;
  var rx = - w/2;
  var ry = - h/2;
  if (fillStyle != null) {
    g.fillStyle = fillStyle;
    g.fillRect(rx, ry, w, h);
  }
  if (strokeStyle != null) {
    g.strokeStyle = strokeStyle;
    g.lineWidth = strokeLineWidth;
    g.lineDashOffset = strokeLineDashOffset;
    g.strokeRect(rx, ry, w, h);
  }
  area.x = w.toDouble();
  area.y = h.toDouble();
};

DrawCanvas dot4({fillStyle}) => (CanvasRenderingContext2D g, Entity e, area) {
  if (fillStyle != null) {
    g.fillStyle = fillStyle;
    g.fillRect(-2, -2, 4, 4);
    area.x = 4.0;
    area.y = 4.0;
  }
};

DrawCanvas disc(num radius, {fillStyle, strokeStyle, strokeLineWidth : 1, strokeLineDashOffset : 0})  => (CanvasRenderingContext2D g, Entity e, area) {
  if (strokeStyle == null && fillStyle == null) return;
  g.beginPath();
  g.arc(0, 0, radius,0, math.PI*2,true);
  g.closePath();
  if (fillStyle != null) {
    g.fillStyle = fillStyle;
    g.fill();
  }
  if (strokeStyle != null) {
    g.strokeStyle = strokeStyle;
    g.lineWidth = strokeLineWidth;
    g.lineDashOffset = strokeLineDashOffset;
    g.stroke();
  }
  area.x = radius.toDouble();
  area.y = radius.toDouble();
};

DrawCanvas text(String txt, {fillStyle, strokeStyle, strokeLineWidth : 1, strokeLineDashOffset : 0, textAlign : null, font: null})  => (CanvasRenderingContext2D g, Entity e,area) {
  if (strokeStyle == null && fillStyle == null) return;
  //if (textAlign != null) g.textAlign = textAlign;
  if (fillStyle != null) {
    g.fillStyle = fillStyle;
    g.fillText(txt, 0, 0);
  }
  if (strokeStyle != null) {
    g.strokeStyle = strokeStyle;
    g.lineWidth = strokeLineWidth;
    g.lineDashOffset = strokeLineDashOffset;
    if (font != null) g.font = font;
    g.strokeText(txt, 0, 0);
  }
  //TODO var m = g.measureText(txt);
  //TODO area.x = m.width;
  //TODO area.y = m.h;
};

//DrawCanvas particles(num radius, {fillStyle, strokeStyle, strokeLineWidth : 1, strokeLineDashOffset : 0}){
//  return (CanvasRenderingContext2D g, Entity entity, area) {
//    var particle0s = entity.getComponent(Particles.CT) as Particles;
//    if (particle0s == null || particle0s.position3d.isEmpty) return;
//    if (strokeStyle == null && fillStyle == null) return;
//    g.beginPath();
//    particle0s.position3d.forEach((pos) {
//      if (pos != null) {
//        g.moveTo(pos.x + radius, pos.y);
//        //print('${pos.x} // ${pos.y}');
//        g.arc(pos.x, pos.y, radius, 0, math.PI*2,true);
//      }
//    });
//    g.closePath();
//    if (fillStyle != null) {
//      g.fillStyle = fillStyle;
//      g.fill();
//    }
//    if (strokeStyle != null) {
//      g.strokeStyle = strokeStyle;
//      g.lineWidth = strokeLineWidth;
//      g.lineDashOffset = strokeLineDashOffset;
//      g.stroke();
//    }
//    //TODO define the area
////    area.x = radius.toDouble();
////    area.y = radius.toDouble();
//  };
//}

//DrawCanvas particleInfo0s(num radius, {fillStyle, strokeStyle, strokeLineWidth : 1, strokeLineDashOffset : 0}){
//  return (CanvasRenderingContext2D g, Entity entity, area) {
//    var particle0s = entity.getComponent(Particles.CT) as Particles;
//    if (particle0s == null || particle0s.position3d.isEmpty) return;
//    var particleInfo0s = entity.getComponent(ParticleInfo0s.CT) as ParticleInfo0s;
//    if (particleInfo0s == null || particleInfo0s.l.isEmpty) {
//      return particles(radius, fillStyle : fillStyle, strokeStyle : strokeStyle, strokeLineWidth : strokeLineWidth, strokeLineDashOffset : strokeLineDashOffset)(g, entity, area);
//    }
//    for(var i = particle0s.position3d.length - 1; i > -1; --i){
//      var pos = particle0s.position3d[i];
//      if (pos != null) {
//        var p0 = particleInfo0s.l[i];
//        var radius0 = (p0 != null) ? p0.radius * p0.scale : radius;
//        var fillStyle0 = (p0 != null) ? irgba_rgbaString(p0.color) : fillStyle;
//        //g.moveTo(pos.x, pos.y);
//        g.beginPath();
//        //print('${pos.x} // ${pos.y}');
//        g.arc(pos.x, pos.y, radius0, 0, math.PI*2,true);
//        g.closePath();
//        if (fillStyle != null) {
//          g.fillStyle = fillStyle0;
//          g.fill();
//        }
//        if (strokeStyle != null) {
//          g.strokeStyle = strokeStyle;
//          g.lineWidth = strokeLineWidth;
//          g.lineDashOffset = strokeLineDashOffset;
//          g.stroke();
//        }
//      }
//    }
//    //TODO define the area
////    area.x = radius.toDouble();
////    area.y = radius.toDouble();
//  };
//}
DrawCanvas particles(num radiusScale, {fillStyle, strokeStyle, strokeLineWidth : 1, strokeLineDashOffset : 0, radiusMin : 0.0}){
  return (CanvasRenderingContext2D g, Entity entity, area) {
    var particle0s = entity.getComponent(Particles.CT) as Particles;
    if (particle0s == null || particle0s.position3d.isEmpty) return;
    for(var i = particle0s.length - 1; i > -1; --i){
      var pos = particle0s.position3d[i];
      if (pos != null) {
        var radius0 = math.max(particle0s.radius[i] * radiusScale, radiusMin);
        int color = particle0s.color[i];
        if (particle0s.collide[i] == -1) {
          color = hsl_irgba(hsl_complement(irgba_hsl(color)));
        } else if (!particle0s.isSim[i]) {
          color = hsl_irgba(hsl_triad(irgba_hsl(color))[1]);
        }
        var fillStyle0 = irgba_rgbaString(color);
        //g.moveTo(pos.x, pos.y);
        g.beginPath();
        //print('${pos.x} // ${pos.y}');
        g.arc(pos.x, pos.y, radius0, 0, math.PI*2,true);
        g.closePath();
        if (fillStyle != null) {
          g.fillStyle = fillStyle0;
          g.fill();
        }
        if (strokeStyle != null) {
          g.strokeStyle = strokeStyle;
          g.lineWidth = strokeLineWidth;
          g.lineDashOffset = strokeLineDashOffset;
          g.stroke();
        }
      }
    }
    //TODO define the area
//    area.x = radius.toDouble();
//    area.y = radius.toDouble();
  };
}

DrawCanvas segments({pinStyle : "rgba(0,153,255,0.1)", distanceStyle : "#d8dde2", distanceStyleCollide : "#e2ddd8"}) => (CanvasRenderingContext2D g, Entity e, area) {
  var ss = e.getComponent(Segments.CT) as Segments;
  ss.l.forEach((x) {
    drawSegment(g, x, distanceStyle, distanceStyleCollide);
  });
};

drawSegment(g, Segment x, strokeStyle, strokeStyleCollide) {
  var p1 = x.ps.position3d[x.i1];
  var p2 = x.ps.position3d[x.i2];
  g.beginPath();
  g.moveTo(p1.x, p1.y);
  g.lineTo(p2.x, p2.y);
  g.strokeStyle = (x.collide == -1) ? strokeStyleCollide : strokeStyle; //
  g.stroke();
}


var printCanvas = null;

printPoly(List<Vector3> poly, int color) {
  if (printCanvas == null) return;
  var g = printCanvas;
  g.beginPath();
  g.moveTo(poly[poly.length - 1].x, poly[poly.length - 1].y);
  for(var i = 0; i < poly.length; i++) {
    g.lineTo(poly[i].x, poly[i].y);
  }
  var tmp = g.lineWidth;
  g.lineWidth = 5;
  g.strokeStyle = irgba_rgbaString(color);
  g.stroke();
  g.lineWidth = tmp;
}