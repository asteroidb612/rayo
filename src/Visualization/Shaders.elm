module Visualization.Shaders exposing
    ( Uniforms
    , fragment
    , shadowFragment
    , vertex
    , wireframeFragment
    )

{-| This file contains shaders that are used in examples.
Shaders support simple flat lighting.
-}

import Math.Matrix4 exposing (Mat4)
import Math.Vector2 exposing (Vec2)
import Math.Vector3 exposing (Vec3)
import Visualization.Meshes exposing (Attributes)
import WebGL exposing (Shader)
import WebGL.Texture exposing (Texture)


type alias Uniforms =
    { camera : Mat4
    , perspective : Mat4
    , transform : Mat4
    , color : Vec3
    , lightDirection : Vec3
    , texture : Texture
    }


vertex : Shader Attributes Uniforms { vlighting : Float, vcoord : Vec2 }
vertex =
    [glsl|
        attribute vec3 position;
        attribute vec3 normal;
        attribute vec2 coords;
        uniform mat4 camera;
        uniform mat4 perspective;
        uniform mat4 transform;
        uniform vec3 lightDirection;
        varying float vlighting;
        varying vec2 vcoord;
        void main () {
          float ambientLight = 0.4;
          float directionalLight = 0.6;
          gl_Position = perspective * camera * transform * vec4(position, 1.0);
          vec4 transformedNormal = normalize(transform * vec4(normal, 0.0));
          float directional = max(dot(transformedNormal.xyz, lightDirection), 0.0);
          vlighting = ambientLight + directional * directionalLight;
          vcoord = coords.xy;
        }
    |]


fragment : Shader {} Uniforms { vlighting : Float, vcoord : Vec2 }
fragment =
    -- gl_FragColor = vec4(vlighting * color, 1.0);
    -- gl_FragColor = texture2D(texture, vcoord);
    [glsl|
        precision mediump float;
        uniform vec3 color;
        uniform sampler2D texture;
        varying float vlighting;
        varying vec2 vcoord;

        void main () {
          gl_FragColor = texture2D(texture, vcoord) + vec4(vlighting * color, 1.0) - .7 ;
        }
    |]


wireframeFragment : Shader {} Uniforms { vlighting : Float, vcoord : Vec2 }
wireframeFragment =
    [glsl|
        precision mediump float;
        uniform vec3 color;
        varying float vlighting;
        varying vec2 vcoord;
        void main () {
          gl_FragColor = vec4(color, 1.0);
        }
    |]


shadowFragment : Shader {} Uniforms { vlighting : Float, vcoord : Vec2 }
shadowFragment =
    [glsl|
        precision mediump float;
        uniform vec3 color;
        varying float vlighting;
        varying vec2 vcoord;
        void main () {
          gl_FragColor = vec4(color, 1);
        }
    |]
