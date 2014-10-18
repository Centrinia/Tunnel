import 'dart:html';
import 'package:vector_math/vector_math.dart';
import 'dart:web_gl' as webgl;
import 'dart:typed_data';
import 'dart:math';
import 'dart:async';

class CubeVertex {
  int _axis;
  int _direction;
  Vector3 _position;
  Vector3 _texcoords;
  bool _hasTexture;
  /*
   * Make a cube vertex where the center is given by position, 
   * the cube edge length is 2*radius, and the direction gives
   * the sign of the respective axis of the face.
   */
  CubeVertex(Vector3 position, double radius, int axis, int direction, List<double> squareVertex, bool hasTexture) {
    _axis = axis;
    _direction = direction;
    _texcoords = new Vector3.zero();
    _hasTexture = hasTexture;

    _position = new Vector3.copy(position);
    var d = direction != 0 ? radius : -radius;
    _position[axis] += d;
    int index = 0;
    for (int i = 0; i < 3; i++) {
      if (i != axis) {
        _position[i] += squareVertex[index] != 0 ? radius : -radius;
        _texcoords[index] = squareVertex[index] != 0 ? 1.0 : 0.0;
        index++;
      }
    }
  }
  List<double> dumpPosition() {
    List<double> buffer = new List<double>(3);
    _position.copyIntoArray(buffer);
    return buffer;
  }
  List<double> dumpFaceNormal() {
    List<double> normal = [0.0, 0.0, 0.0];
    normal[_axis] = _direction != 0 ? 1.0 : -1.0;
    return normal;
  }
  List<double> dumpTexcoords() {
    List<double> buffer = new List<double>(3);
    _texcoords.copyIntoArray(buffer);
    return buffer;
  }
}

/**
 * A link to a song.
 */
class Link {
  String _name;
  String _imageURI;
  Link(String name, String imageURI) {
    _name = name;
    _imageURI = imageURI;
  }


}
class Cube {
  double _radius;
  List<CubeVertex> _vertexes;
  Vector3 _position;
  List<bool> _hasSide;
  List<Cube> _neighbors;
  List<Link> _links;
  Cube() : this.positioned(new Vector3.zero());

  
  Cube.positioned(Vector3 position, [double radius = 32.0]) {
    _radius = radius;
    _links = new List<Link>(6);
    _position = new Vector3.zero();
    _hasSide = new List<bool>(6);
    for (int i = 0; i < 6; i++) {
      _hasSide[i] = true;
    }


    _neighbors = new List<Cube>(6);
    _initBuffer();
  }
  void addLink(int axis, int direction, Link link)
  {
    if(_hasSide[axis*2+direction]){
    _links[axis*2+direction] = link;
    }
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
  void _initBuffer() {
    _vertexes = new List<CubeVertex>();
    //var squareVertexes = [[0, 0], [1, 0], [1, 1], [0, 1]];
    var squareVertexes = [[0, 0], [0, 1], [1, 1], [1, 0]];
    // Generate the vertexes.
    for (int i = 0; i < 6; i++) {
      if (_hasSide[i]) {
        int direction = i % 2;
        int axis = i ~/ 2;

        for (int j = 0; j < 4; j++) {
          int j_rev = ((direction != 0) != (axis % 2 == 1)) ? j : 3 - j;
          _vertexes.add(new CubeVertex(_position, _radius, axis, direction, squareVertexes[j_rev], _links[i] != null));
        }
      }
    }

    // fill "current buffer" with triangle verticies
    //vertices = [1.0, 1.0, 0.0, -1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0, 0.0];
    //_gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(vertices), webgl.RenderingContext.STATIC_DRAW);
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
  /*webgl.Buffer _vertexPositionBuffer;
  webgl.Buffer _vertexNormalBuffer;*/
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



    int length = _random.nextInt(length_limit-1)+1;

    Cube middle;
    length = _random.nextInt(length_limit-1)+1;

    for (int i = 0; i < length; i++) {
      middle = new Cube();
      nearmiddle.connectCube(2, 1, middle);
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
     length = _random.nextInt(length_limit-1)+1;

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
  Level(webgl.RenderingContext gl) {
    _random = new Random();
    _numFaces = 0;
    _gl = gl;
    _cubes = new List<Cube>();

    _startCube = new Cube();
    _cubes.add(_startCube);
    _recursiveAddCube(_startCube, 12,10);

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
  /**
   * @param cube the cube that the player is in.
   */
  void makeBuffers(Cube startingCube) {
    List<double> buffer = new List<double>();

    /*for (var cube in _cubes) {
      buffer.addAll(cube.dumpBuffer());
    }*/
    /* Determine visibility. */
    _traverseCubes(startingCube, (cube) {
      buffer.addAll(cube.dumpBuffer());
    }, 2);

    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexBuffer);
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(buffer), webgl.RenderingContext.STATIC_DRAW);

    _numFaces = buffer.length ~/ (stride);
  }
  final int dimensions = 3;
  final int stride = (3 * 4) * 3;
  final int positionOffset = 0;
  final int normalOffset = 3 * 4;
  void render(int aVertexPosition, int aVertexNormal) {
    for (int i = 0; i < _numFaces; i++) {
      _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexBuffer);

      _gl.vertexAttribPointer(aVertexPosition, dimensions, webgl.RenderingContext.FLOAT, false, stride, i * stride * 4 + positionOffset);

      _gl.vertexAttribPointer(aVertexNormal, dimensions, webgl.RenderingContext.FLOAT, false, stride, i * stride * 4 + normalOffset);
      _gl.drawArrays(webgl.RenderingContext.TRIANGLE_FAN, 0, 4);
      //_gl.drawArrays(webgl.RenderingContext.LINE_LOOP, 0, 4);
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

  Camera _camera;
  Vector3 _momentum;
  Cube _cube;

  Player(Cube cube) {
    _camera = new Camera();
    _momentum = new Vector3.zero();
    _cube = cube;
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

  void advance() {
    Vector3 new_position = _camera._position + _momentum;

    bool hit_wall = false;
    for (int axis = 0; axis < 3; axis++) {
      double diff = new_position[axis] - _cube._position[axis];
      if ((diff + RADIUS).abs() > _cube._radius && !_noclipping) {
        int direction = diff + RADIUS > 0 ? 1 : 0;
        if (_cube._hasSide[axis * 2 + direction]) {
          hit_wall = true;
          Vector3 normal = new Vector3.zero();
          normal[axis] = 1.0 - direction * 2.0;
          _momentum.reflect(normal);
          _momentum *= FRICTION;
          new_position = _camera._position + _momentum;
        } else {
          _cube = _cube._neighbors[axis * 2 + direction];
        }
      }
    }


    _camera._position = new_position;
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
  Vector3 _position;
  Vector3 _up;
  Vector3 _direction;
  Camera() {
    _position = new Vector3(0.0, 0.0, 0.0);
    _up = new Vector3(0.0, 1.0, 0.0);
    _direction = new Vector3(0.0, 0.0, 1.0);
  }
  Matrix4 getModelviewMatrix() {
    return makeViewMatrix(_position, _position + _direction, _up);
  }

  /**
   * Look up by the given radians.
   */
  void yaw_up(double angle) {
    Quaternion quat = new Quaternion.axisAngle(_direction.cross(_up), -angle);
    _direction = quat.rotate(_direction);
    _up = quat.rotate(_up);
  }

  /**
   * Turn the camera around the _up vector by the given radians.
   */
  void turn_left(double angle) {
    Quaternion quat = new Quaternion.axisAngle(_up, -angle);
    _direction = quat.rotate(_direction);
  }

  /**
   * Roll the camera counterclockwise around the _direction vector by the given radians.
   */
  void roll_left(double angle) {
    Quaternion quat = new Quaternion.axisAngle(_direction, angle);
    _up = quat.rotate(_up);
  }
  /**
   * Move the camera forward by the given amount.
   */
  void move_forward(double amount) {
    _position += _direction * amount;
  }
  /**
   * Move the camera to the left by the given amount.
   */
  void move_left(double amount) {
    _position -= left * amount;
  }

  Vector3 get left => _direction.cross(_up);

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

  webgl.UniformLocation _uPMatrix;
  webgl.UniformLocation _uNMatrix;
  webgl.UniformLocation _uMVMatrix;
  Cube _currentCube;
  

  Game(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;
    _gl = canvas.getContext("experimental-webgl");

    _initShaders();

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.enable(webgl.RenderingContext.DEPTH_TEST);


    _level = new Level(_gl);
    _player = new Player(_level._startCube);
  }


  void _initShaders() {
    // vertex shader source code. uPosition is our variable that we'll
    // use to create animation
    String vsSource = """
    attribute vec3 vPosition;
    attribute vec3 vNormal;

    uniform mat4 uMVMatrix;
    uniform mat3 uNMatrix;
    uniform mat4 uPMatrix;
    varying vec3 fPosition;
    varying vec3 fNormal;
    varying vec3 fColor;
    void main(void) {
        vec4 mvPos = uMVMatrix * vec4(vPosition, 1.0);
        gl_Position = uPMatrix * mvPos;
        fPosition = mvPos.xyz / mvPos.w;
        fColor = (vNormal+1.0)/2.0;
        fNormal = uNMatrix * vNormal;
    }
    """;

    // fragment shader source code. uColor is our variable that we'll
    // use to animate color
    String fsSource = """
    precision mediump float;
    varying vec3 fPosition;
    varying vec3 fNormal;
    varying vec3 fColor;
    void main(void) {
        float attenuation = 0.0;
        float radiusLight = 30.0 / dot(fPosition,fPosition);
        attenuation += max(0.0, dot(fNormal, normalize(fPosition))); 
        attenuation += max(min(radiusLight,1.0),0.1);
        vec3 color = fColor;
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
    try {
      _gl.enableVertexAttribArray(_aVertexPosition);
    } on Exception {

    }
    _aVertexNormal = _gl.getAttribLocation(_shaderProgram, "vNormal");
    try {
      _gl.enableVertexAttribArray(_aVertexNormal);
    } on Exception {

    }
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
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clearColor(0, 0, 0, 1);
    _gl.enable(webgl.RenderingContext.CULL_FACE);
    _gl.cullFace(webgl.RenderingContext.BACK);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    // field of view is 90°, width-to-height ratio, hide things closer than 0.1 or further than 100
    _pMatrix = makePerspectiveMatrix(radians(90.0), _viewportWidth / _viewportHeight, 0.1, FAR_DISTANCE);

    _mvMatrix = _player._camera.getModelviewMatrix();
    _setMatrixUniforms();

    if(_currentCube != _player._cube){
    _level.makeBuffers(_player._cube);
    _currentCube = _player._cube;
    }
    _level.render(_aVertexPosition, _aVertexNormal);

  }

  void _handleKey(KeyboardEvent e) {
    const INVERT_VERTICAL = -1;
    switch (e.keyCode) {
      //case KeyCode.W:
      case KeyCode.COMMA:
        _player.move_forward(FORWARD_AMOUNT / TICS_PER_SECOND);
        break;
      //case KeyCode.S:
      case KeyCode.O:
        _player.move_forward(-BACKWARD_AMOUNT / TICS_PER_SECOND);
        break;
      case KeyCode.A:
              _player.move_left(STRAFE_AMOUNT / TICS_PER_SECOND);
        break;
      //case KeyCode.D:
      case KeyCode.E:
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

void main() {
  Game game = new Game(querySelector('#game'));
  //window.console.log(level._startCube.dumpBuffer());
  game.startTimer();
}
