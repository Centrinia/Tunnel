import 'dart:html';
import 'package:vector_math/vector_math.dart';
import 'dart:web_gl' as webgl;
import 'dart:typed_data';

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
    _radius = 1.0;
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
  }
  void _initBuffer() {
    _vertexes = new List<CubeVertexes>();
    //var squareVertexes = [[0, 0], [1, 0], [1, 1], [0, 1]];
    var squareVertexes = [[0, 0], [0, 1], [1, 1], [1, 0]];
    // Generate the vertexes.
    for (int i = 0; i < 6; i++) {
      if (_hasSide[i]) {
        int direction = i % 2;
        int axis = i ~/ 2;

        for (int j = 0; j < 4; j++) {
          _vertexes.add(new CubeVertex(_position, _radius, axis, direction, squareVertexes[j]));
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
  int numVertexes() {
    return _vertexes.length;
  }

  void render() {

  }
}
class Level {
  int _numFaces;
  webgl.Buffer _vertexPositionBuffer;
  Cube _startCube;
  List<Cube> _cubes;
  webgl.RenderingContext _gl;
  Level(webgl.RenderingContext gl) {
    _numFaces = 0;
    _gl = gl;
    _cubes = new List<Cube>();
    
    _startCube = new Cube([0.0, 0.0, 0.0]);
    var neighbor = new Cube([0.0,0.0,0.0]);
    _startCube.connectCube(2, 1, neighbor);
    _cubes.add(_startCube);
    _cubes.add(neighbor);
  }

  

  void initBuffers() {
    // create square
    _vertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexPositionBuffer);

    // fill "current buffer" with triangle verticies
    List<double> positions = new List<double>();
    
    for(var cube in _cubes) {
      positions.addAll(cube.dumpPositionBuffer());
    }

    window.console.log(positions);
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(positions), webgl.RenderingContext.STATIC_DRAW);
    _numFaces = positions.length~/12;
  }

  void render(int aVertexPosition) {
    int dimensions = 3;

    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _vertexPositionBuffer);
    for(int i=0;i<_numFaces;i++) {
    _gl.vertexAttribPointer(aVertexPosition, dimensions, webgl.RenderingContext.FLOAT, false, 0, i*4*3*4);
    //_gl.drawArrays(webgl.RenderingContext.TRIANGLE_FAN, 0, 4); // square, start at 0, total 4
    _gl.drawArrays(webgl.RenderingContext.LINE_LOOP, 0, 4); // square, start at 0, total 4
    }
  }
}

/**
 * based on:
 * http://learningwebgl.com/blog/?p=28
 * https://github.com/BoldInventions/dart-webgl-tutorials/blob/master/web/lesson_01/Lesson_01.dart
 */
class Game {

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
  webgl.UniformLocation _uPMatrix;
  webgl.UniformLocation _uMVMatrix;


  Game(CanvasElement canvas) {
    _viewportWidth = canvas.width;
    _viewportHeight = canvas.height;
    _gl = canvas.getContext("experimental-webgl");

    _initShaders();
    _initBuffers();

    _gl.clearColor(0.0, 0.0, 0.0, 1.0);
    _gl.enable(webgl.RenderingContext.DEPTH_TEST);
    _level = new Level(_gl);
  }


  void _initShaders() {
    // vertex shader source code. uPosition is our variable that we'll
    // use to create animation
    String vsSource = """
    attribute vec3 aVertexPosition;

    uniform mat4 uMVMatrix;
    uniform mat4 uPMatrix;

    void main(void) {
        gl_Position = uPMatrix * uMVMatrix * vec4(aVertexPosition, 1.0);
    }
    """;

    // fragment shader source code. uColor is our variable that we'll
    // use to animate color
    String fsSource = """
    precision mediump float;

    void main(void) {
        gl_FragColor = vec4(1.0, 1.0, 1.0, 1.0);
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

    _aVertexPosition = _gl.getAttribLocation(_shaderProgram, "aVertexPosition");
    _gl.enableVertexAttribArray(_aVertexPosition);

    _uPMatrix = _gl.getUniformLocation(_shaderProgram, "uPMatrix");
    _uMVMatrix = _gl.getUniformLocation(_shaderProgram, "uMVMatrix");

  }

  void _initBuffers() {
    // variable to store verticies
    List<double> vertices;

    // create triangle
    _triangleVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _triangleVertexPositionBuffer);

    // fill "current buffer" with triangle verticies
    vertices = [0.0, 1.0, 0.0, -1.0, -1.0, 0.0, 1.0, -1.0, 0.0];
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(vertices), webgl.RenderingContext.STATIC_DRAW);

    //_triangleVertexPositionBuffer.itemSize = 3;
    //_triangleVertexPositionBuffer.numItems = 3;

    // create square
    _squareVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _squareVertexPositionBuffer);

    // fill "current buffer" with triangle verticies
    vertices = [1.0, 1.0, 0.0, -1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0, 0.0];
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(vertices), webgl.RenderingContext.STATIC_DRAW);

  }

  void _setMatrixUniforms() {
    Float32List tmpList = new Float32List(16);

    _pMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uPMatrix, false, tmpList);

    _mvMatrix.copyIntoArray(tmpList);
    _gl.uniformMatrix4fv(_uMVMatrix, false, tmpList);
  }

  void render() {
    _gl.viewport(0, 0, _viewportWidth, _viewportHeight);
    _gl.clearColor(1, 0, 0, 1);
    _gl.clear(webgl.RenderingContext.COLOR_BUFFER_BIT | webgl.RenderingContext.DEPTH_BUFFER_BIT);

    // field of view is 45°, width-to-height ratio, hide things closer than 0.1 or further than 100
    _pMatrix = makePerspectiveMatrix(radians(45.0), _viewportWidth / _viewportHeight, 0.1, 100.0);

    _mvMatrix = new Matrix4.identity();
    _mvMatrix.translate(new Vector3(-1.5, 0.0, -7.0));
    _setMatrixUniforms();

    //_gl.cullFace(webgl.RenderingContext.FRONT_AND_BACK);

    _level.initBuffers();
    _level.render(_aVertexPosition);
    //_gl.drawArrays(webgl.RenderingContext.TRIANGLE_STRIP, 0, 4*6);

    // create square
    /*var _squareVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _squareVertexPositionBuffer);

    // fill "current buffer" with triangle verticies
    List<double> vertices = _level._startCube.dumpPositionBuffer();
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(vertices), webgl.RenderingContext.STATIC_DRAW);

    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _squareVertexPositionBuffer);
    _gl.vertexAttribPointer(_aVertexPosition, _dimensions, webgl.RenderingContext.FLOAT, false, 0, 0);
    _setMatrixUniforms();
    _gl.drawArrays(webgl.RenderingContext.TRIANGLE_STRIP, 0, 4*6); // square, start at 0, total 4

    window.console.log(vertices);*/

/*
    // create square
    var _squareVertexPositionBuffer = _gl.createBuffer();
    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _squareVertexPositionBuffer);

    // fill "current buffer" with triangle verticies
    List<double> vertices = [1.0, 1.0, 0.0, -1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0, 0.0];
    _gl.bufferDataTyped(webgl.RenderingContext.ARRAY_BUFFER, new Float32List.fromList(vertices), webgl.RenderingContext.STATIC_DRAW);

    _gl.bindBuffer(webgl.RenderingContext.ARRAY_BUFFER, _squareVertexPositionBuffer);
    _gl.vertexAttribPointer(_aVertexPosition, _dimensions, webgl.RenderingContext.FLOAT, false, 0, 0);
    _setMatrixUniforms();
    _gl.drawArrays(webgl.RenderingContext.TRIANGLE_STRIP, 0, 4); // square, start at 0, total 4

    window.console.log(vertices);
*/
    
  }

}

void main() {
  Game game = new Game(querySelector('#game'));
  //window.console.log(level._startCube.dumpBuffer());
  game.render();
}
