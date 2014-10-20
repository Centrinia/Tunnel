import 'dart:html';
import 'dart:convert';
import 'package:vector_math/vector_math.dart';
import 'dart:web_gl' as webgl;
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';
import 'dart:collection';
import 'dart:web_audio' as snd;


class CubeVertex {
  int _axis;
  int _direction;
  Vector3 _position;
  Vector2 _texcoords;
  Vector2 _texatlas;
  bool _hasTexture;
  /*
   * Make a cube vertex where the center is given by position, 
   * the cube edge length is 2*radius, and the direction gives
   * the sign of the respective axis of the face.
   */
  CubeVertex(Vector3 position, double radius, int axis, int direction, List<double> squareVertex, Link link) {
    _axis = axis;
    _direction = direction;
    if (link != null) {
      //_texatlas = new Vector2.copy(link.texatlas);
      _texatlas = new Vector2(1.0, 1.0);
    } else {
      _texatlas = new Vector2(-1.0, -1.0);
    }
    _texcoords = new Vector2.zero();
    _hasTexture = link != null;

    _position = new Vector3.copy(position);
    var d = direction != 0 ? radius : -radius;
    _position[axis] += d;
    int index = 0;
    for (int i = 0; i < 3; i++) {
      if (i != axis) {
        int reverse_index = (axis % 2) == direction ? 1 - index : index;

        _position[i] += squareVertex[index] != 0 ? radius : -radius;
        _texcoords[index] = squareVertex[reverse_index] != 0 ? 1.0 : 0.0;
        index++;
      }
    }
  }
  List<double> dumpPosition() {
    List<double> buffer = new List<double>(4);
    _position.copyIntoArray(buffer);
    buffer[3] = 0.0;
    return buffer;
  }
  List<double> dumpFaceNormal() {
    List<double> normal = [0.0, 0.0, 0.0, 0.0];
    normal[_axis] = _direction != 0 ? 1.0 : -1.0;
    return normal;
  }
  List<double> dumpTexcoords() {
    List<double> buffer = new List<double>(4);
    _texcoords.copyIntoArray(buffer);
    _texatlas.copyIntoArray(buffer, 2);
    return buffer;
  }
}

/**
 * A link to a song.
 */
class Link {
  String _songName;
  String _albumName;
  String _artistName;
  String _previewURL;
  String _imageURL;
  ImageElement _image;
  bool _imageReady;
  webgl.Texture _texture;
  webgl.RenderingContext _gl;

  Link(webgl.RenderingContext gl, snd.AudioContext audioContext, String songName, String albumName, String artistName, String previewURL, String imageURL) {
    _gl = gl;
    _audioContext = audioContext;
    _playing = false;

    _songName = songName;
    _albumName = albumName;
    _artistName = artistName;
    _previewURL = previewURL;
    _imageURL = imageURL;

    _image = new ImageElement();
    _imageReady = false;
    _texture = _gl.createTexture();
    _image.onLoad.listen((e) {
      _gl.bindTexture(webgl.TEXTURE_2D, _texture);
      _gl.texImage2DImage(webgl.TEXTURE_2D, 0, webgl.RGBA, webgl.RGBA, webgl.UNSIGNED_BYTE, _image);
      _gl.texParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MIN_FILTER, webgl.NEAREST);
      _gl.texParameteri(webgl.TEXTURE_2D, webgl.TEXTURE_MAG_FILTER, webgl.NEAREST);
      _imageReady = true;
    }, onError: (e) => print(e));
    _image.src = imageURL;
    counter += 1.0;

  }


  static double counter = 0.0;
  /*Vector2 get texAtlas {

    return new Vector2(counter, 0.0);
  }*/
  void bindTexture() {
    if (_imageReady) {
      _gl.bindTexture(webgl.TEXTURE_2D, _texture);
    }

  }
  snd.AudioContext _audioContext;
  snd.AudioBufferSourceNode _source;
  bool _playing;
  void startSong() {
    if (_playing) {
      return;
    }
    HttpRequest request = new HttpRequest();
    request.open("GET", _previewURL, async: true);
    request.responseType = "arraybuffer";
    request.onLoad.listen((e) {
      window.console.log(request.response);
      _audioContext.decodeAudioData(request.response).then((snd.AudioBuffer buffer) {

        if (buffer == null) {
          window.console.warn("Error decoding file data: $_previewURL");
          return;
        }
        _source = _audioContext.createBufferSource();

        _source.buffer = buffer;
        _source.connectNode(_audioContext.destination);
        _source.start(0);
        _playing = true;
      });
    });
    request.onError.listen((e) => window.console.warn("BufferLoader: XHR error"));
    request.send();

  }

  void stopSong() {
    if (_playing) {
      _source.stop(0);
      _playing = false;
    }
  }

  Vector2 get texatlas => new Vector2(0.5, 0.5);
}
class Cube {
  double _radius;
  List<CubeVertex> _vertexes;
  Vector3 _position;
  List<bool> _hasSide;
  List<Cube> _neighbors;
  List<Link> _links;
  List<Vector3> _normals;
  ArtistTree _artistTree;
  Cube() : this.positioned(new Vector3.zero());


  Cube.positioned(Vector3 position, [double radius = 32.0]) {
    _radius = radius;
    _links = new List<Link>(6);
    _position = new Vector3.zero();
    _hasSide = new List<bool>(6);
    _normals = new List<Vector3>(6);
    for (int i = 0; i < 6; i++) {
      _hasSide[i] = true;
    }


    _neighbors = new List<Cube>(6);
    _initBuffer();
  }
  void addLink(int axis, int direction, Link link) {
    if (_hasSide[axis * 2 + direction]) {
      _links[axis * 2 + direction] = link;
    }
    _initBuffer();
  }
  void connectCube(int axis, int direction, Cube neighbor) {
    _hasSide[axis * 2 + direction] = false;
    _neighbors[axis * 2 + direction] = neighbor;

    neighbor._hasSide[axis * 2 + (1 - direction)] = false;
    neighbor._neighbors[axis * 2 + (1 - direction)] = this;

    neighbor._position = new Vector3.copy(_position);
    double d = _radius + neighbor._radius;
    d = direction != 0 ? d : -d;
    neighbor._position[axis] += d;

    neighbor._initBuffer();
    _initBuffer();
  }
  void visit() {

  }
  void _initBuffer() {
    _vertexes = new List<CubeVertex>();

    var squareVertexes = [[0, 0], [0, 1], [1, 1], [1, 0]];
    // Generate the vertexes.
    for (int i = 0; i < 6; i++) {
      int direction = i % 2;
      int axis = i ~/ 2;
      _normals[i] = new Vector3.zero();
      _normals[i][axis] = direction != 0 ? -1.0 : 1.0;
      if (_hasSide[i]) {
        for (int j = 0; j < 4; j++) {
          int j_rev = ((direction != 0) != (axis % 2 == 1)) ? j : 3 - j;
          _vertexes.add(new CubeVertex(_position, _radius, axis, direction, squareVertexes[j_rev], _links[i]));
        }
      }
    }
  }
  List<double> dumpPositionBuffer() {
    List<double> buffer = new List<double>();
    for (var vertex in _vertexes) {
      buffer.addAll(vertex.dumpPosition());
    }
    return buffer;
  }
  List<double> dumpNormalBuffer() {
    List<double> buffer = new List<double>();
    for (var vertex in _vertexes) {
      buffer.addAll(vertex.dumpFaceNormal());
    }
    return buffer;
  }
  List<double> dumpBuffer() {
    List<double> buffer = new List<double>();
    for (var vertex in _vertexes) {
      buffer.addAll(vertex.dumpPosition());
      buffer.addAll(vertex.dumpFaceNormal());
      buffer.addAll(vertex.dumpTexcoords());
    }
    return buffer;
  }
  int numVertexes() {
    return _vertexes.length;
  }

}
class Level {
  int _numFaces;

  webgl.Buffer _vertexBuffer;
  Cube _startCube;
  List<Cube> _cubes;
  webgl.RenderingContext _gl;
  Cube _previousCube;
  Random _random;
  void _addCube(int axis, int direction) {
    var neighbor = new Cube();
    _previousCube.connectCube(axis, direction, neighbor);
    _cubes.add(neighbor);
    _previousCube = neighbor;

  }

  void _recursiveAddCube(Cube root, int levels, [int length_limit = 4]) {
    if (levels == 0) {
      return;
    }

    Cube nearmiddle;
    nearmiddle = new Cube();
    root.connectCube(2, 1, nearmiddle);
    _cubes.add(nearmiddle);

    int length = _random.nextInt(length_limit - 1) + 1;

    Cube middle;
    length = _random.nextInt(length_limit - 1) + 1;

    for (int i = 0; i < length; i++) {
      middle = new Cube();
      nearmiddle.connectCube(2, 1, middle);

      Link link = _links[_random.nextInt(_links.length)];
      nearmiddle.addLink(_random.nextInt(3), _random.nextInt(2), link);

      _cubes.add(middle);
      nearmiddle = middle;
    }

    int new_axis = _random.nextInt(2);

    Cube left = new Cube();
    middle.connectCube(new_axis, 0, left);
    _cubes.add(left);


    Cube farleft;
    for (int i = 0; i < length; i++) {
      farleft = new Cube();
      left.connectCube(new_axis, 0, farleft);
      _cubes.add(farleft);
      left = farleft;
    }

    new_axis = _random.nextInt(2);
    length = _random.nextInt(length_limit - 1) + 1;

    Cube right = new Cube();
    middle.connectCube(new_axis, 1, right);
    _cubes.add(right);


    Cube farright;
    for (int i = 0; i < length; i++) {
      farright = new Cube();
      right.connectCube(new_axis, 1, farright);
      _cubes.add(farright);
      right = farright;
    }

    _recursiveAddCube(farleft, levels - 1);
    _recursiveAddCube(farright, levels - 1);
  }
  snd.AudioContext _audioContext;
  List<Link> _links;

  Level(webgl.RenderingContext gl, snd.AudioContext audioContext) {
    _gl = gl;
    _audioContext = audioContext;

    _links = new List<Link>();
    _links.add(new Link(_gl, _audioContext, "New Age Messiah", "Amok", "Sentenced", "media/out.mp3", "media/out.jpg"));
    _links.add(new Link(_gl, _audioContext, "The Primeval Dark", "Above The Weeping World", "Insomnium", "media/out2.mp3", "media/out2.jpg"));
    _links.add(new Link(_gl, _audioContext, "The Hunt", "Winterborn", "Wolfheart", "media/out3.mp3", "media/out3.jpg"));


    _random = new Random();
    _numFaces = 0;
    _cubes = new List<Cube>();

    _startCube = new Cube();
    _cubes.add(_startCube);
    _recursiveAddCube(_startCube, 12, 10);

    _initBuffers();
  }



  void _initBuffers() {
    for (Cube cube in _cubes) {
      cube._initBuffer();
    }
    _vertexBuffer = _gl.createBuffer();
  }

  void _traverseCubesDirection(Cube cube, int axis, int direction, Function func(Cube c)) {
    Cube current = cube;
    while (!current._hasSide[axis * 2 + direction]) {
      current = current._neighbors[axis * 2 + direction];
      func(current);
    }
  }

  void _traverseCubes(Cube cube, Function func(Cube c), [depth = 2]) {
    func(cube);
    if (depth == 0) {
      return;
    }
    for (int index = 0; index < 6; index++) {
      _traverseCubesDirection(cube, index ~/ 2, index % 2, (Cube cube2) {
        _traverseCubes(cube2, func, depth - 1);
      });
    }
  }
  List<Link> _faceLinks;

  /**
   * @param startingCube the cube that the player is in.
   */
  void makeBuffers(Cube startingCube) {
    List<double> buffer = new List<double>();

    _faceLinks = new List<Link>();
    /* Determine visibility. */
    _traverseCubes(startingCube, (cube) {
      buffer.addAll(cube.dumpBuffer());
      for (int i = 0; i < 6; i++) {
        if (cube._hasSide[i]) {
          _faceLinks.add(cube._links[i]);
        }
      }
    }, 2);

    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexBuffer);
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(buffer), webgl.RenderingContext.STATIC_DRAW);

    _numFaces = buffer.length ~/ stride;
  }
  static final int dimensions = 4;
  static final int stride = (dimensions * 4) * 3;
  static final int positionOffset = 0;
  static final int normalOffset = dimensions * 4;
  static final int texCoordOffset = dimensions * 4 * 2;
  static final int texAtlasOffset = dimensions * 4 * 2 + dimensions * 2;

  void render(int aVertexPosition, int aVertexNormal, int aTexCoord, int aTexAtlas) {
    Map<Link, List<int>> linkTextures = new HashMap<Link, List<int>>();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexBuffer);
    _gl.vertexAttribPointer(aVertexPosition, 3, webgl.RenderingContext.FLOAT, false, stride, positionOffset);
    _gl.vertexAttribPointer(aVertexNormal, 3, webgl.RenderingContext.FLOAT, false, stride, normalOffset);
    _gl.vertexAttribPointer(aTexCoord, 2, webgl.RenderingContext.FLOAT, false, stride, texCoordOffset);
    _gl.vertexAttribPointer(aTexAtlas, 2, webgl.RenderingContext.FLOAT, false, stride, texAtlasOffset);


    for (int i = 0; i < _numFaces; i++) {
      Link link = _faceLinks[i];
      if (link != null) {
        if (linkTextures[link] == null) {
          linkTextures[link] = new List<int>();
        }
        linkTextures[link].add(i);
      } else {
        /* Draw the flat. */
        _gl.drawArrays(webgl.RenderingContext.TRIANGLE_FAN, i * 4, 4);
      }
    }

    for (Link link in linkTextures.keys) {

      link.bindTexture();

      for (int i in linkTextures[link]) {

        _gl.drawArrays(webgl.RenderingContext.TRIANGLE_FAN, i * 4, 4);
      }
    }
  }

}

/**
 * The player object.
 */
class Player {
  static final _noclipping = false;
  static const RADIUS = 0.5;
  static final DRAG = pow(0.2, 1.0 / Game.TICS_PER_SECOND);
  static final FRICTION = 0.8;
  Link _currentLink;

  Camera _camera;
  Vector3 _momentum;
  Cube _cube;

  Player(Cube cube) {
    _camera = new Camera();
    _momentum = new Vector3.zero();
    _cube = cube;
    _currentLink = null;
  }

  void impulse(Vector3 direction) {
    _momentum += direction;
  }

  void move_forward(double amount) {
    impulse(_camera._direction * amount);
  }
  void move_left(double amount) {
    impulse(_camera.left * -amount);
  }

  static final CRASH_THRESHOLD = 2;
  void advance() {
    Vector3 new_position = _camera.position + _momentum;

    bool hit_wall = false;
    for (int axis = 0; axis < 3; axis++) {
      double diff = new_position[axis] - _cube._position[axis];
      if ((diff + RADIUS).abs() > _cube._radius && !_noclipping) {
        int direction = diff + RADIUS > 0 ? 1 : 0;
        if (_cube._hasSide[axis * 2 + direction]) {
          /* Activate the music preview if there is a link and the player crashes into the album art with enough speed. */
          //window.console.log(_momentum.dot(_cube._normals[axis * 2 + direction]));
          if (_cube._links[axis * 2 + direction] != null && -_momentum.dot(_cube._normals[axis * 2 + direction]) > CRASH_THRESHOLD) {
            _currentLink = _cube._links[axis * 2 + direction];
            _currentLink.stopSong();
            _currentLink.startSong();
          }
          hit_wall = true;
          Vector3 normal = new Vector3.zero();
          normal[axis] = 1.0 - direction * 2.0;
          _momentum.reflect(normal);
          _momentum *= FRICTION;
          new_position = _camera.position + _momentum;
        } else {
          if (_currentLink != null) {
            _currentLink.stopSong();
            _currentLink = null;
          }
          _cube = _cube._neighbors[axis * 2 + direction];
          _cube.visit();
        }
      }
    }


    _camera.position = new_position;
    _momentum *= DRAG;
  }
  void turn_left(double angle) {
    _camera.turn_left(angle);
  }
  void roll_left(double angle) {
    _camera.roll_left(angle);
  }
  void yaw_up(double angle) {
    _camera.yaw_up(angle);
  }
}

/**
 * The camera.
 */
class Camera {
  bool need_update;
  Vector3 _position;
  Vector3 _up;
  Vector3 _direction;
  Camera() {
    _position = new Vector3(0.0, 0.0, 0.0);
    _up = new Vector3(0.0, 1.0, 0.0);
    _direction = new Vector3(0.0, 0.0, 1.0);
    need_update = true;
  }
  Matrix4 getModelviewMatrix() {
    need_update = false;
    return makeViewMatrix(_position, _position + _direction, _up);
  }

  /**
   * Look up by the given radians.
   */
  void yaw_up(double angle) {
    Quaternion quat = new Quaternion.axisAngle(_direction.cross(_up), -angle);
    _direction = quat.rotate(_direction);
    _up = quat.rotate(_up);
    need_update = angle != 0.0;
  }

  /**
   * Turn the camera around the _up vector by the given radians.
   */
  void turn_left(double angle) {
    Quaternion quat = new Quaternion.axisAngle(_up, -angle);
    _direction = quat.rotate(_direction);
    need_update = angle != 0.0;
  }

  /**
   * Roll the camera counterclockwise around the _direction vector by the given radians.
   */
  void roll_left(double angle) {
    Quaternion quat = new Quaternion.axisAngle(_direction, angle);
    _up = quat.rotate(_up);
    need_update = angle != 0.0;

  }
  /**
   * Move the camera forward by the given amount.
   */
  void move_forward(double amount) {
    _position += _direction * amount;
    need_update = amount != 0.0;
  }
  /**
   * Move the camera to the left by the given amount.
   */
  void move_left(double amount) {
    _position -= left * amount;
    need_update = amount != 0.0;
  }

  static const THRESHOLD = 1e-5;
  Vector3 get left => _direction.cross(_up);
  Vector3 get position => _position;
  set position(Vector3 new_position) {
    if (new_position.relativeError(position) > THRESHOLD) {
      need_update = true;
      _position = new_position;
    }
  }
}

/**
 * based on:
 * http://learningwebgl.com/blog/?p=28
 * https://github.com/BoldInventions/dart-webgl-tutorials/blob/master/web/lesson_01/Lesson_01.dart
 */
class Game {
  static const TICS_PER_SECOND = 35;
  static const double FAR_DISTANCE = 10000.0;
  /**
   * Forward speed in terms of length units per second.
   */
  static const double FORWARD_AMOUNT = 12.0;
  static const double BACKWARD_AMOUNT = 7.0;
  static const double STRAFE_AMOUNT = 8.0;
  /**
   * Yaw speed in terms of radians per second.
   */
  static const double YAW_AMOUNT = 120 * 2 * PI / 360;
  static const double ROLL_AMOUNT = 120 * 2 * PI / 360;
  static const double TURN_AMOUNT = 120 * 2 * PI / 360;
  Player _player;
  Level _level;
  Keyboard _keyboard;

  CanvasElement _canvas;
  webgl.RenderingContext _gl;
  webgl.Buffer _triangleVertexPositionBuffer;
  webgl.Buffer _squareVertexPositionBuffer;
  webgl.Program _shaderProgram;
  int _dimensions = 3;
  int _viewportWidth;
  int _viewportHeight;

  Matrix4 _pMatrix;
  Matrix4 _mvMatrix;

  int _aVertexPosition;
  int _aVertexNormal;
  int _aVertexTexCoord;
  int _aVertexTexAtlas;

  webgl.UniformLocation _uPMatrix;
  webgl.UniformLocation _uNMatrix;
  webgl.UniformLocation _uMVMatrix;

  Cube _currentCube;
  snd.AudioContext _audioContext;

  Game(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;
    canvas.onClick.listen((e) {
      canvas.requestFullscreen();
      canvas.width = window.innerWidth;
      canvas.height = window.innerHeight;
    });

    canvas.onFullscreenChange.listen((e) {
      _viewportWidth = canvas.width;
      _viewportHeight = canvas.height;
    });

    _gl = canvas.getContext("experimental-webgl");

    _initShaders();

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.enable(webgl.RenderingContext.DEPTH_TEST);


    _audioContext = new snd.AudioContext();

    _level = new Level(_gl, _audioContext);
    _player = new Player(_level._startCube);
  }


  void _initShaders() {
    // vertex shader source code. uPosition is our variable that we'll
    // use to create animation
    String vsSource = """
    attribute vec3 vPosition;
    attribute vec3 vNormal;
    attribute vec2 vTexCoord;
    attribute vec2 vTexAtlas;
    uniform mat4 uMVMatrix;
    uniform mat3 uNMatrix;
    uniform mat4 uPMatrix;
    varying vec3 fPosition;
    varying vec3 fNormal;
    varying vec3 fColor;
    varying vec2 fTexCoord;
    varying vec2 fTexAtlas;
    void main(void) {

        vec4 mvPos = uMVMatrix * vec4(vPosition, 1.0);
        gl_Position = uPMatrix * mvPos;
        fPosition = mvPos.xyz / mvPos.w;
        fColor = (vNormal+1.0)/2.0;
        fNormal = uNMatrix * vNormal;
        fTexCoord = vTexCoord;
        fTexAtlas = vTexAtlas;
    }
    """;

    // fragment shader source code. uColor is our variable that we'll
    // use to animate color
    String fsSource = """
    precision mediump float;
    uniform sampler2D uSampler;
    varying vec3 fPosition;
    varying vec3 fNormal;
    varying vec3 fColor;
    varying vec2 fTexCoord;
    varying vec2 fTexAtlas;
    void main(void) {
        float attenuation = 0.0;
        float radiusLight = 30.0 / dot(fPosition,fPosition);
        attenuation += max(0.0, dot(fNormal, normalize(fPosition))); 
        attenuation += max(min(radiusLight,1.0),0.1);
        vec3 color;
        if(fTexAtlas != vec2(-1.0, -1.0)){
            color = texture2D(uSampler, fTexCoord).rgb;
        } else {
          color = fColor;
        }

        gl_FragColor = vec4(color * attenuation,1.0);
    }
    """;

    // vertex shader compilation
    webgl.Shader vs = _gl.createShader(webgl.RenderingContext.VERTEX_SHADER);
    _gl.shaderSource(vs, vsSource);
    _gl.compileShader(vs);

    // fragment shader compilation
    webgl.Shader fs = _gl.createShader(webgl.RenderingContext.FRAGMENT_SHADER);
    _gl.shaderSource(fs, fsSource);
    _gl.compileShader(fs);

    // attach shaders to a WebGL program
    _shaderProgram = _gl.createProgram();
    _gl.attachShader(_shaderProgram, vs);
    _gl.attachShader(_shaderProgram, fs);
    _gl.linkProgram(_shaderProgram);
    _gl.useProgram(_shaderProgram);

    /**
     * Check if shaders were compiled properly. This is probably the most painful part
     * since there's no way to "debug" shader compilation
     */
    if (!_gl.getShaderParameter(vs, webgl.RenderingContext.COMPILE_STATUS)) {
      print(_gl.getShaderInfoLog(vs));
    }

    if (!_gl.getShaderParameter(fs, webgl.RenderingContext.COMPILE_STATUS)) {
      print(_gl.getShaderInfoLog(fs));
    }

    if (!_gl.getProgramParameter(_shaderProgram, webgl.RenderingContext.LINK_STATUS)) {
      print(_gl.getProgramInfoLog(_shaderProgram));
    }

    _aVertexPosition = _gl.getAttribLocation(_shaderProgram, "vPosition");
    _gl.enableVertexAttribArray(_aVertexPosition);

    _aVertexNormal = _gl.getAttribLocation(_shaderProgram, "vNormal");
    _gl.enableVertexAttribArray(_aVertexNormal);

    _aVertexTexCoord = _gl.getAttribLocation(_shaderProgram, "vTexCoord");
    _gl.enableVertexAttribArray(_aVertexTexCoord);
    _aVertexTexAtlas = _gl.getAttribLocation(_shaderProgram, "vTexAtlas");
    _gl.enableVertexAttribArray(_aVertexTexAtlas);

    _uPMatrix = _gl.getUniformLocation(_shaderProgram, "uPMatrix");
    _uNMatrix = _gl.getUniformLocation(_shaderProgram, "uNMatrix");
    _uMVMatrix = _gl.getUniformLocation(_shaderProgram, "uMVMatrix");

  }

  void _setMatrixUniforms() {
    Float32List tmpList = new Float32List(16);


    _pMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uPMatrix, false, tmpList);

    _mvMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uMVMatrix, false, tmpList);

    tmpList = new Float32List(9);
    Matrix3 nMatrix = new Matrix3.columns(_mvMatrix.row0.xyz, _mvMatrix.row1.xyz, _mvMatrix.row2.xyz);
    nMatrix.invert();
    nMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix3fv(_uNMatrix, false, tmpList);

  }


  void _render() {
    if (!_player._camera.need_update) {
      return;
    }

    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clearColor(0, 0, 0, 1);
    _gl.enable(webgl.RenderingContext.CULL_FACE);
    _gl.cullFace(webgl.RenderingContext.BACK);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    // field of view is 90°, width-to-height ratio, hide things closer than 0.1 or further than 100
    _pMatrix = makePerspectiveMatrix(radians(90.0), _viewportWidth / _viewportHeight, 0.1, FAR_DISTANCE);

    _mvMatrix = _player._camera.getModelviewMatrix();
    _setMatrixUniforms();

    if (_currentCube != _player._cube) {
      _level.makeBuffers(_player._cube);
      _currentCube = _player._cube;
    }
    _level.render(_aVertexPosition, _aVertexNormal, _aVertexTexCoord, _aVertexTexAtlas);
  }

  void _handleKey(KeyboardEvent e) {
    const INVERT_VERTICAL = -1;
    switch (e.keyCode) {
      case KeyCode.W:
        //case KeyCode.COMMA:
        _player.move_forward(FORWARD_AMOUNT / TICS_PER_SECOND);
        break;
      case KeyCode.S:
        //case KeyCode.O:
        _player.move_forward(-BACKWARD_AMOUNT / TICS_PER_SECOND);
        break;
      case KeyCode.A:
        _player.move_left(STRAFE_AMOUNT / TICS_PER_SECOND);
        break;
      case KeyCode.D:
        //case KeyCode.E:
        _player.move_left(-STRAFE_AMOUNT / TICS_PER_SECOND);
        break;

      case KeyCode.LEFT:
        if (e.shiftKey) {
          _player.roll_left(ROLL_AMOUNT / TICS_PER_SECOND);
        } else {
          _player.turn_left(TURN_AMOUNT / TICS_PER_SECOND);
        }
        break;
      case KeyCode.RIGHT:
        if (e.shiftKey) {
          _player.roll_left(-ROLL_AMOUNT / TICS_PER_SECOND);
        } else {
          _player.turn_left(-TURN_AMOUNT / TICS_PER_SECOND);
        }
        break;


      case KeyCode.UP:
        _player.yaw_up(YAW_AMOUNT * INVERT_VERTICAL / TICS_PER_SECOND);
        break;
      case KeyCode.DOWN:
        _player.yaw_up(-YAW_AMOUNT * INVERT_VERTICAL / TICS_PER_SECOND);
        break;
    }
  }


  void _gameloop(Timer timer) {
    for (int keyCode in _keyboard._keys.keys) {

      _handleKey(_keyboard._keys[keyCode]);
    }
    _player.advance();
    _render();
  }

  Timer startTimer() {
    const duration = const Duration(milliseconds: 1000 ~/ TICS_PER_SECOND);
    _keyboard = new Keyboard();

    return new Timer.periodic(duration, _gameloop);
  }
}

/**
 * http://stackoverflow.com/questions/13746105/how-to-listen-to-key-press-repetitively-in-dart-for-games
 */
class Keyboard {
  Map<int, KeyboardEvent> _keys = new Map<int, KeyboardEvent>();

  Keyboard() {
    window.onKeyDown.listen((KeyboardEvent e) {
      // If the key is not set yet, set it with a timestamp.
      if (!_keys.containsKey(e.keyCode)) _keys[e.keyCode] = e;
    });

    window.onKeyUp.listen((KeyboardEvent e) {
      _keys.remove(e.keyCode);
    });
  }

  /**
   * Check if the given key code is pressed. You should use the [KeyCode] class.
   */
  isPressed(int keyCode) => _keys.containsKey(keyCode);
}

class ArtistTree {
  String _artistName;
  List<String> _similars;
  ArtistTree(String name) {
    _artistName = name;
  }
  static const API_KEY = "FILDTEOIK2HBORODV";
  void getSimilars() {
    HttpRequest request = new HttpRequest();
    int resultsCount = 15;
    int server_port = 8006;
    String requestURL = "http://localhost:$server_port/foo?artist=$_artistName";
    window.console.log(requestURL);
    request.open("GET", requestURL, async: true);
    request.onLoad.listen((e) {
      window.console.log(request.response);
      List parsedJSON = JSON.decode(request.responseText);
      _similars = new List<String>();
      for (Map x in parsedJSON) {
        _similars.add(x['name']);
      }
    });
    request.onError.listen((e) => window.console.warn("XHR error"));
    request.send();
  }
}

void main() {
  Game game = new Game(querySelector('#game'));
  //window.console.log(level._startCube.dumpBuffer());
  game.startTimer();
}
