module Visualization.Scene exposing (view)

import Direction3d exposing (Direction3d)
import Frame3d
import Geometry.Interop.LinearAlgebra.Direction3d as Direction3d
import Geometry.Interop.LinearAlgebra.Frame3d as Frame3d
import Geometry.Interop.LinearAlgebra.Point3d as Point3d
import Html exposing (Html)
import Html.Attributes as Attributes
import Length exposing (Meters)
import Math.Matrix4 as Mat4 exposing (Mat4)
import Math.Vector3 as Vec3 exposing (Vec3)
import Physics.Body as Body exposing (Body)
import Physics.Contact as Contact
import Physics.Coordinates exposing (BodyCoordinates, WorldCoordinates)
import Physics.World as World exposing (RaycastResult, World)
import Point3d exposing (Point3d)
import Visualization.Camera exposing (Camera)
import Visualization.Math as Math
import Visualization.Meshes as Meshes exposing (Meshes)
import Visualization.Settings exposing (Settings)
import Visualization.Shaders as Shaders
import WebGL exposing (Entity)
import WebGL.Texture exposing (Texture)


type alias Params a =
    { settings : Settings
    , world : World a
    , camera : Camera
    , meshes : a -> Meshes
    , maybeRaycastResult : Maybe (RaycastResult a)
    , floorOffset :
        { x : Float
        , y : Float
        , z : Float
        }
    , texture : Texture
    }


view : Params a -> Html msg
view { settings, world, floorOffset, camera, maybeRaycastResult, meshes, texture } =
    let
        lightDirection =
            Vec3.normalize (Vec3.vec3 -1 -1 -4)

        sceneParams =
            { lightDirection = lightDirection
            , camera = camera
            , debugWireframes = settings.debugWireframes
            , debugCenterOfMass = settings.debugCenterOfMass
            , maybeRaycastResult = maybeRaycastResult
            , meshes = meshes
            , shadow =
                Math.makeShadow
                    (Vec3.fromRecord floorOffset)
                    Vec3.k
                    lightDirection
            , texture = texture
            }
    in
    WebGL.toHtmlWith
        [ WebGL.depth 1
        , WebGL.alpha True
        , WebGL.antialias
        , WebGL.clearColor 0.3 0.3 0.3 1
        ]
        [ Attributes.width (round camera.width)
        , Attributes.height (round camera.height)
        , Attributes.style "position" "absolute"
        , Attributes.style "top" "0"
        , Attributes.style "left" "0"
        ]
        ([ ( True
           , \entities -> List.foldl (addBodyEntities sceneParams) entities (World.bodies world)
           )
         , ( settings.debugContacts
           , \entities -> List.foldl (addContactIndicator sceneParams) entities (getContactPoints world)
           )
         ]
            |> List.filter Tuple.first
            |> List.map Tuple.second
            |> List.foldl (<|) []
        )


getContactPoints : World a -> List (Point3d Meters WorldCoordinates)
getContactPoints world =
    world
        |> World.contacts
        |> List.concatMap Contact.points
        |> List.map .point


type alias SceneParams a =
    { lightDirection : Vec3
    , camera : Camera
    , debugWireframes : Bool
    , debugCenterOfMass : Bool
    , shadow : Mat4
    , maybeRaycastResult : Maybe (RaycastResult a)
    , meshes : a -> Meshes
    , texture : Texture
    }


addBodyEntities : SceneParams a -> Body a -> List Entity -> List Entity
addBodyEntities ({ meshes, lightDirection, shadow, camera, debugWireframes, debugCenterOfMass, maybeRaycastResult, texture } as sceneParams) body entities =
    let
        transform =
            Frame3d.toMat4 (Body.frame body)

        color =
            Vec3.vec3 0.9 0.9 0.9

        showRayCastNormal =
            False

        addNormals acc =
            case maybeRaycastResult of
                Just res ->
                    if showRayCastNormal && Body.data res.body == Body.data body then
                        addNormalIndicator sceneParams transform { normal = res.normal, point = res.point } acc

                    else
                        acc

                Nothing ->
                    acc

        addCenterOfMass acc =
            if debugCenterOfMass then
                addContactIndicator sceneParams (Point3d.placeIn (Body.frame body) (Body.centerOfMass body)) acc

            else
                acc

        { mesh, wireframe } =
            meshes (Body.data body)
    in
    entities
        |> addCenterOfMass
        |> addNormals
        |> (if debugWireframes then
                (::)
                    (WebGL.entity
                        Shaders.vertex
                        Shaders.wireframeFragment
                        wireframe
                        { camera = camera.cameraTransform
                        , perspective = camera.perspectiveTransform
                        , color = color
                        , lightDirection = lightDirection
                        , transform = transform
                        , texture = texture
                        }
                    )

            else
                (::)
                    (WebGL.entity
                        Shaders.vertex
                        Shaders.fragment
                        mesh
                        { camera = camera.cameraTransform
                        , perspective = camera.perspectiveTransform
                        , color = color
                        , lightDirection = lightDirection
                        , transform = transform
                        , texture = texture
                        }
                    )
           )
        |> (if debugWireframes then
                identity

            else
                (::)
                    (WebGL.entity
                        Shaders.vertex
                        Shaders.shadowFragment
                        mesh
                        { camera = camera.cameraTransform
                        , perspective = camera.perspectiveTransform
                        , color = Vec3.vec3 0.25 0.25 0.25
                        , lightDirection = lightDirection
                        , transform = Mat4.mul shadow transform
                        , texture = texture
                        }
                    )
           )


{-| Render a collision point for the purpose of debugging
-}
addContactIndicator : SceneParams a -> Point3d Meters WorldCoordinates -> List Entity -> List Entity
addContactIndicator { lightDirection, camera, texture } point tail =
    WebGL.entity
        Shaders.vertex
        Shaders.fragment
        Meshes.contact
        { camera = camera.cameraTransform
        , perspective = camera.perspectiveTransform
        , color = Vec3.vec3 1 0 0
        , lightDirection = lightDirection
        , transform = Frame3d.toMat4 (Frame3d.atPoint point)
        , texture = texture
        }
        :: tail


{-| Render a normal for the purpose of debugging
-}
addNormalIndicator : SceneParams a -> Mat4 -> { point : Point3d Meters BodyCoordinates, normal : Direction3d BodyCoordinates } -> List Entity -> List Entity
addNormalIndicator { lightDirection, camera, texture } transform { normal, point } tail =
    WebGL.entity
        Shaders.vertex
        Shaders.fragment
        Meshes.normal
        { camera = camera.cameraTransform
        , perspective = camera.perspectiveTransform
        , lightDirection = lightDirection
        , color = Vec3.vec3 1 0 1
        , transform =
            Math.makeRotateKTo (Direction3d.toVec3 normal)
                |> Mat4.mul
                    (Point3d.toVec3 point
                        |> Mat4.makeTranslate
                        |> Mat4.mul transform
                    )
        , texture = texture
        }
        :: tail
