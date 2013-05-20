// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.
//
// In jurisdictions that recognize copyright laws, the author or authors
// of this software dedicate any and all copyright interest in the
// software to the public domain. We make this dedication for the benefit
// of the public at large and to the detriment of our heirs and
// successors. We intend this dedication to be an overt act of
// relinquishment in perpetuity of all present and future rights to this
// software under copyright law.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
// IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
// OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
// OTHER DEALINGS IN THE SOFTWARE.
//
// For more information, please refer to <http://unlicense.org/>
library system_simple_audio;

import 'package:dartemis/dartemis.dart';
import 'package:dartemis_toolbox/utils.dart';
import 'package:dartemis_toolbox/transform.dart';
import 'package:simple_audio/simple_audio.dart';

/**
 * Component use to store a bag of name of [AudioClip] to play.
 * When the [System_Audio] start to play, name is removed from the bag.
 * [System_Audio] start to play ASAP.
 */
class AudioDef extends ComponentPoolable {
  final l = new LinkedBag<String>();

  /// only one entity can be the audioListener at time t.
  var isAudioListener = false;

  AudioDef._();
  static _ctor() => new AudioDef._();
  factory AudioDef() {
    var c = new Poolable.of(AudioDef, _ctor);
    c.cleanUp();
    return c;
  }

  void cleanUp() {
    l.clear();
    isAudioListener = false;
  }

  /// this is a sugar method for [l].add([a])
  /// sugar because you can write
  ///
  ///    new AudioDef()
  ///      ..add("boost")
  ///      ..add("alarm")
  ///
  AudioDef add(String a) {
    l.add(a);
    return this;
  }
}

class _AudioCache extends Component {
  final AudioSource source;

  _AudioCache(this.source);
}
/// ClipProvider find an AudioClip from name;
/// eg a clipProvider from assetPackManager :
///
///     (name) => _assetManager[name]
///
typedef AudioClip ClipProvider(String name);

class System_Audio extends EntityProcessingSystem {
  ComponentMapper<Transform> _transformMapper;
  ComponentMapper<AudioDef> _objDefMapper;
  ComponentMapper<_AudioCache> _objCacheMapper;

  var _listener;
  var _positional = false;
  final AudioManager _audioManager;

  ClipProvider _clipProvider;

  /// [clipProvider] is the function to find AudioClip from name,
  /// default implementation is [clipProvider0]
  System_Audio(this._audioManager, {clipProvider, positional : false}):
    super(Aspect.getAspectForAllOf([AudioDef])),
    _positional = positional {
    _clipProvider = (clipProvider == null) ? this.clipProvider0 : clipProvider;
  }

  void initialize(){
    _transformMapper = new ComponentMapper<Transform>(Transform, world);
    _objDefMapper = new ComponentMapper<AudioDef>(AudioDef, world);
    _objCacheMapper = new ComponentMapper<_AudioCache>(_AudioCache, world);
  }

  /// a default implementation for clipProvider, that retreive clip from [AudioManager]
  ///   (x) = > _audioManager.findClip(x);
  AudioClip clipProvider0(x) => _audioManager.findClip(x);

  void processEntity(entity) {
    var cache = _objCacheMapper.getSafe(entity);
    if (cache != null) {
      var obj = cache.source;
      _applyTransform(obj, entity);
      var def = _objDefMapper.get(entity);
      def.l.iterateAndUpdate((x) {
        var clip = _clipProvider(x);
        if (clip == null) {
          //TODO log("can't play sound '${x}' : notfound in audioManager nor assetManager");
        } else {
          //TODO log("play ${x} : ${_assetManager.getAssetAtPath(x).url} : ${clip}");
          if (obj != _listener) {
            obj.playOnce(clip);
          } else {
            _audioManager.music.stop();
            _audioManager.music.clip = clip;
            _audioManager.music.play(loop : false);
          }
        }
        return null;
      });
    }
  }

  void inserted(Entity entity){
    var objDef = _objDefMapper.get(entity);
    var obj = _audioManager.makeSource(entity.id.toString());
    entity.addComponent(new _AudioCache(obj));
    entity.changedInWorld();
    _applyTransform(obj, entity);
    if (objDef.isAudioListener) {
      //log("set audiolistener");
      _listener = obj;
    }
  }

  void removed(Entity entity){
    var cache = _objCacheMapper.getSafe(entity);
    if (cache != null) {
      cache.source.stop();
      if (cache.source == _listener) _listener = null;
    }
    entity.removeComponent(_AudioCache);
    //log("removed audio ${entity}");
  }

  void _applyTransform(obj, Entity entity) {
    if (! _positional) return;
    var tf = _transformMapper.getSafe(entity);
    if (obj != null && tf != null) {
      obj.positional = true;
      obj.setPosition(tf.position3d.x, tf.position3d.y, tf.position3d.z);
      if (obj == _listener) {
        _audioManager.setPosition(tf.position3d.x, tf.position3d.y, tf.position3d.z);
      }
    }
  }

}
