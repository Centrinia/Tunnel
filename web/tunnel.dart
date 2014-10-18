import 'dart:html';
import 'package:vector_math/vector_math.dart';
import 'dart:web_gl' as webgl;
import 'dart:typed_data';
import 'dart:math';

class CubeVertex {
  int _axis;
  int _direction;
  List<double> _position;
  /*
   * Make a cube vertex where the center is given by position, 
   * the cube edge length is 2*radius, and the direction gives
   * the sign of the respective axis of the face.
   */
  CubeVertex(List<double> position, double radius, int axis, int direction, List<double> squareVertex) {
    _axis = axis;
    _direction = direction;

    _position = new List<double>.from(position);
    var d = direction != 0 ? radius : -radius;
    _position[axis] += d;
    int index = 0;
    for (int i = 0; i < 3; i++) {
      if (i != axis) {
        _position[i] += squareVertex[index] != 0 ? radius : -radius;
        index++;
      }
    }
  }
  List<double> dumpPosition() {
    return _position;
  }
  List<double> dumpFaceNormal() {
    List<double> normal = [0.0, 0.0, 0.0];
    normal[_axis] = _direction != 0 ? 1.0 : -1.0;
    return normal;
  }
}

class Cube {
  double _radius;
  List<CubeVertex> _vertexes;
  List<double> _position;
  List<bool> _hasSide;
  List<Cube> _neighbors;
  Cube(List<double> position) {
    _radius = 4.0;
    _position = new List<double>.from(position);
    _hasSide = new List<bool>(6);
    for (int i = 0; i < 6; i++) {
      _hasSide[i] = true;
    }


    _neighbors = new List<Cube>(6);
    _initBuffer();
  }
  void connectCube(int axis, int direction, Cube neighbor) {
    _hasSide[axis * 2 + direction] = false;
    neighbor._hasSide[axis * 2 + (1 - direction)] = false;
    neighbor._position = new List<double>.from(_position);
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
          int j_rev = ((direction != 0) != (axis & 1 == 1)) ? j : 3-j;
          _vertexes.add(new CubeVertex(_position, _radius, axis, direction, squareVertexes[j_rev]));
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
  void _addCube(int axis, int direction) {
    var neighbor = new Cube([0.0, 0.0, 0.0]);
    _previousCube.connectCube(axis, direction, neighbor);
    _cubes.add(neighbor);
    _previousCube = neighbor;

  }
  Level(webgl.RenderingContext gl) {
    _numFaces = 0;
    _gl = gl;
    _cubes = new List<Cube>();

    _startCube = new Cube([0.0, 0.0, 0.0]);
    _cubes.add(_startCube);
    _previousCube = _startCube;
    _addCube(2, 0);
    _addCube(0, 1);
    _addCube(1, 1);
    _addCube(1, 1);
    _addCube(0, 1);
    _addCube(0, 1);
    _addCube(2, 1);
    _addCube(1, 0);
    _addCube(1, 0);
    _addCube(1, 0);
    _addCube(1, 0);
    _addCube(1, 0);

    _initBuffers();
  }



  void _initBuffers() {
    _vertexBuffer = _gl.createBuffer();
   /*_vertexPositionBuffer = _gl.createBuffer();
    _vertexNormalBuffer = _gl.createBuffer();*/
  }

  void makeBuffers() {

    // fill "current buffer" with triangle verticies
    /*List<double> positions = new List<double>();
    List<double> normals = new List<double>();*/
    List<double> buffer = new List<double>();

    for (var cube in _cubes) {
      /*positions.addAll(cube.dumpPositionBuffer());
      normals.addAll(cube.dumpNormalBuffer());*/
      buffer.addAll(cube.dumpBuffer());
    }

    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexBuffer);
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(buffer), webgl.RenderingContext.STATIC_DRAW);
    /*_gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexPositionBuffer);
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(positions), webgl.RenderingContext.STATIC_DRAW);*/
    /*_gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexNormalBuffer);
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(normals), webgl.RenderingContext.STATIC_DRAW);*/
    
    //_numFaces = positions.length ~/ 12;
    _numFaces = buffer.length ~/ (stride);
  }
  final int dimensions = 3;
  final int stride = (3 * 4) * 2;
  final int positionOffset = 0;
  final int normalOffset = 3*4;
  void render(int aVertexPosition, int aVertexNormal) {
    for (int i = 0; i < _numFaces; i++) {
      _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexBuffer);
      //_gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexPositionBuffer);
      _gl.vertexAttribPointer(aVertexPosition, dimensions, webgl.RenderingContext.FLOAT, false, stride, i * stride * 4 + positionOffset);
      //_gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexNormalBuffer);
      _gl.vertexAttribPointer(aVertexNormal, dimensions, webgl.RenderingContext.FLOAT, false, stride, i * stride * 4 + normalOffset);
      _gl.drawArrays(webgl.RenderingContext.TRIANGLE_FAN, 0, 4); // square, start at 0, total 4
      //_gl.drawArrays(webgl.RenderingContext.LINE_LOOP, 0, 4); // square, start at 0, total 4
    }
  }
}

/**
 * 
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
    window.console.log(_position);
    window.console.log(_up);
    window.console.log(_direction);
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
    _position -= _direction.cross(_up) * amount;
  }
}

/**
 * based on:
 * http://learningwebgl.com/blog/?p=28
 * https://github.com/BoldInventions/dart-webgl-tutorials/blob/master/web/lesson_01/Lesson_01.dart
 */
class Game {
  final double FORWARD_AMOUNT = 0.8;
  final double BACKWARD_AMOUNT = 0.8;
  final double STRAFE_AMOUNT = 0.8;
  final double YAW_AMOUNT = 10 * 2 * PI / 360;
  final double ROLL_AMOUNT = 10 * 2 * PI / 360;
  final double TURN_AMOUNT = 10 * 2 * PI / 360;
  Camera _camera;
  Level _level;

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


  Game(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;
    _gl = canvas.getContext("experimental-webgl");

    _initShaders();
    //_initBuffers();

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.enable(webgl.RenderingContext.DEPTH_TEST);

    _camera = new Camera();

    _level = new Level(_gl);
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
        float radiusLight = 10.0 / dot(fPosition,fPosition);
        attenuation += max(0.0, dot(fNormal, normalize(fPosition))); 
        //attenuation += max(min(radiusLight,1.0),0.1);
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

  void render() {
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clearColor(0, 0, 0, 1);
    _gl.enable(webgl.RenderingContext.CULL_FACE);
    _gl.cullFace(webgl.RenderingContext.BACK);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    // field of view is 90°, width-to-height ratio, hide things closer than 0.1 or further than 100
    _pMatrix = makePerspectiveMatrix(radians(90.0), _viewportWidth / _viewportHeight, 0.1, 100.0);

    _mvMatrix = _camera.getModelviewMatrix();
    _setMatrixUniforms();


    _level.makeBuffers();
    _level.render(_aVertexPosition, _aVertexNormal);

  }

  void hookEventHandlers() {
    window.onKeyUp.listen((KeyboardEvent e) {
      switch (e.keyCode) {
        case KeyCode.W:
          _camera.move_forward(FORWARD_AMOUNT);
          break;
        case KeyCode.S:
          _camera.move_forward(-BACKWARD_AMOUNT);
          break;
        case KeyCode.A:
          _camera.move_left(STRAFE_AMOUNT);
          break;
        case KeyCode.D:
          _camera.move_left(-STRAFE_AMOUNT);
          break;

        case KeyCode.LEFT:
          if (e.shiftKey) {
            _camera.roll_left(ROLL_AMOUNT);
          } else {
            _camera.turn_left(TURN_AMOUNT);
          }
          break;
        case KeyCode.RIGHT:
          if (e.shiftKey) {
            _camera.roll_left(-ROLL_AMOUNT);
          } else {
            _camera.turn_left(-TURN_AMOUNT);
          }
          break;


        case KeyCode.UP:
          _camera.yaw_up(YAW_AMOUNT);
          break;
        case KeyCode.DOWN:
          _camera.yaw_up(-YAW_AMOUNT);
          break;

      }
      render();
    });
  }
}

void main() {
  Game game = new Game(querySelector('#game'));
  game.hookEventHandlers();
  //window.console.log(level._startCube.dumpBuffer());
  game.render();
}
