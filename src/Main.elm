port module Main exposing (main)

{-| This demo allows dragging bodies with mouse!

1.  Uses `World.raycast` on mouse down to pick a body
2.  Creates a temporary body at the mouse position
3.  Connects the temporary body with the selected body using a point to point constraint
4.  Moves the temporary body on mouse move
5.  Removes the temporary body on mouse up

-}

import Acceleration
import Angle
import AngularSpeed
import Axis3d
import Block3d
import Browser
import Direction3d
import Duration
import Frame3d
import Html exposing (Html)
import Html.Attributes
import Html.Events exposing (onClick)
import Json.Encode exposing (Value)
import Length
import Mass
import Physics.Body as Body exposing (Body)
import Physics.Constraint as Constraint
import Physics.Material as Material
import Physics.World as World exposing (RaycastResult, World)
import Plane3d
import Point3d
import Sphere3d
import Task
import Vector3d
import Visualization.Camera as Camera exposing (Camera)
import Visualization.Events as Events
import Visualization.Fps as Fps
import Visualization.Meshes as Meshes exposing (Meshes)
import Visualization.Scene as Scene
import Visualization.Settings as Settings exposing (Settings, SettingsMsg, settings)
import WebGL.Texture as Texture exposing (Texture, load)


{-| Each body should have a unique id,
so that we can later tell which one was selected!
-}
type Id
    = Mouse
    | Floor
    | Box Int


type alias Data =
    { meshes : Meshes
    , id : Id
    }


type alias Model =
    { world : World Data
    , fps : List Float
    , settings : Settings
    , camera : Camera
    , maybeRaycastResult : Maybe (RaycastResult Data)
    , maybeTexture : Maybe Texture
    , maybeThing : Maybe Float
    }


type Msg
    = ForSettings SettingsMsg
    | Tick Float
    | Resize Float Float
    | Restart
    | MouseDown { x : Float, y : Float, z : Float }
    | MouseMove { x : Float, y : Float, z : Float }
    | MouseUp { x : Float, y : Float, z : Float }
    | NewNumber Float
    | Roll
    | TextureLoaded Texture
    | TextureLoadFail


port roll : () -> Cmd msg


port changes : (Float -> msg) -> Sub msg


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }


init : () -> ( Model, Cmd Msg )
init _ =
    ( { world = initialWorld
      , fps = []
      , settings = settings
      , camera =
            Camera.camera
                { from = { x = 0, y = 24, z = 40 }
                , to = { x = 0, y = 0, z = 0 }
                }
      , maybeRaycastResult = Nothing
      , maybeTexture = Nothing
      , maybeThing = Nothing
      }
    , Cmd.batch
        [ Events.measureSize Resize
        , Texture.loadWith Texture.nonPowerOfTwoOptions "faded.png"
            |> Task.attempt
                (\result ->
                    case result of
                        Err _ ->
                            TextureLoadFail

                        Ok texture ->
                            TextureLoaded texture
                )
        ]
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TextureLoadFail ->
            ( model, Cmd.none )

        TextureLoaded texture ->
            ( { model | maybeTexture = Just texture }, Cmd.none )

        Roll ->
            ( model, roll () )

        NewNumber i ->
            ( { model | world = worldBuilder i }, Cmd.none )

        ForSettings settingsMsg ->
            ( { model
                | settings = Settings.update settingsMsg model.settings
              }
            , Cmd.none
            )

        Tick dt ->
            ( { model
                | fps = Fps.update dt model.fps
                , world =
                    model.world
                        |> World.simulate (Duration.seconds (2 / 60))
                , maybeThing =
                    model.world
                        |> World.bodies
                        |> List.map Body.angularVelocity
                        |> List.map Vector3d.length
                        |> List.map AngularSpeed.inRadiansPerSecond
                        |> List.sum
                        |> Debug.log "Tick"
                        |> Just
              }
            , Cmd.none
            )

        Resize width height ->
            ( { model | camera = Camera.resize width height model.camera }
            , Cmd.none
            )

        Restart ->
            ( { model | world = initialWorld }, Cmd.none )

        MouseDown direction ->
            let
                maybeRaycastResult =
                    model.world
                        -- only allow clicks on boxes
                        |> World.keepIf
                            (\body ->
                                case (Body.data body).id of
                                    Box _ ->
                                        True

                                    _ ->
                                        False
                            )
                        |> World.raycast
                            (Axis3d.through
                                (Point3d.fromMeters model.camera.from)
                                (Direction3d.unsafe direction)
                            )
            in
            case maybeRaycastResult of
                Just raycastResult ->
                    -- create temporary body and constrain it
                    -- with selected body
                    let
                        worldPosition =
                            Point3d.placeIn (Body.frame raycastResult.body) raycastResult.point
                    in
                    ( { model
                        | maybeRaycastResult = maybeRaycastResult
                        , world =
                            model.world
                                |> World.add (Body.moveTo worldPosition mouse)
                                |> World.constrain
                                    (\b1 b2 ->
                                        if (Body.data b1).id == Mouse && (Body.data b2).id == (Body.data raycastResult.body).id then
                                            [ Constraint.pointToPoint
                                                Point3d.origin
                                                raycastResult.point
                                            ]

                                        else
                                            []
                                    )
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        MouseMove newDirection ->
            case model.maybeRaycastResult of
                -- move the mouse
                Just raycastResult ->
                    let
                        -- the new position is an intersection
                        -- of the newDirection from the camera and a plane,
                        -- that is defined by the camera direction
                        -- and a point from the raycastResult
                        mouseRay =
                            Axis3d.through
                                (Point3d.fromMeters model.camera.from)
                                (Direction3d.unsafe newDirection)

                        worldPoint =
                            Point3d.placeIn
                                (Body.frame raycastResult.body)
                                raycastResult.point

                        plane =
                            Plane3d.through
                                worldPoint
                                (Direction3d.unsafe newDirection)
                    in
                    ( { model
                        | world =
                            World.update
                                (\body ->
                                    if (Body.data body).id == Mouse then
                                        case Axis3d.intersectionWithPlane plane mouseRay of
                                            Just intersection ->
                                                Body.moveTo intersection body

                                            Nothing ->
                                                body

                                    else
                                        body
                                )
                                model.world
                      }
                    , Cmd.none
                    )

                Nothing ->
                    ( model, Cmd.none )

        MouseUp _ ->
            -- remove the temporary body on mouse up
            ( { model
                | maybeRaycastResult = Nothing
                , world =
                    World.keepIf
                        (Body.data >> .id >> (/=) Mouse)
                        model.world
              }
            , Cmd.none
            )


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Events.onResize Resize
        , Events.onAnimationFrameDelta Tick
        , changes NewNumber
        ]


view : Model -> Html Msg
view { settings, fps, world, camera, maybeRaycastResult, maybeTexture } =
    case maybeTexture of
        Nothing ->
            Html.text "Loading texture"

        Just texture ->
            Html.div
                [ Events.onMouseDown camera MouseDown
                , Events.onMouseMove camera MouseMove
                , Events.onMouseUp camera MouseUp
                ]
                [ Scene.view
                    { settings = settings
                    , world = world
                    , camera = camera
                    , meshes = .meshes
                    , maybeRaycastResult = maybeRaycastResult
                    , floorOffset = floorOffset
                    , texture = texture
                    }
                , Settings.view ForSettings
                    settings
                    [ Html.button [ onClick Restart ]
                        [ Html.text "Restart the demo" ]
                    , Html.button [ onClick Roll ]
                        [ Html.text "Roll" ]
                    ]
                , if settings.showFpsMeter then
                    Fps.view fps (List.length (World.bodies world))

                  else
                    Html.text ""
                , Html.div
                    [ onClick Roll
                    , Html.Attributes.style "position" "absolute"
                    , Html.Attributes.style "width" "75%"
                    , Html.Attributes.style "bottom" "2em"
                    , Html.Attributes.style "background" "white"
                    , Html.Attributes.style "text-align" "center"
                    , Html.Attributes.style "font-size" "300%"
                    , Html.Attributes.style "border-radius" "20px"
                    ]
                    [ Html.text "Roll three d20" ]
                ]


initialWorld : World Data
initialWorld =
    worldBuilder 8.0


worldBuilder : Float -> World Data
worldBuilder seed =
    World.empty
        |> World.withGravity (Acceleration.metersPerSecondSquared 9.80665) Direction3d.negativeZ
        |> World.add floor
        |> World.add
            (box 1
                |> Body.rotateAround Axis3d.y (Angle.radians (-pi / 5))
                |> Body.moveTo (Point3d.meters 0 0 (2 + 1))
            )
        |> World.add
            (box 2
                |> Body.moveTo (Point3d.meters 0.5 0 (1 + seed))
            )
        |> World.add
            (box 3
                |> Body.rotateAround
                    (Axis3d.through Point3d.origin (Direction3d.unsafe { x = 0.7071, y = 0.7071, z = 0 }))
                    (Angle.radians (pi / 5))
                |> Body.moveTo (Point3d.meters -1.2 0 (1 + 5))
            )


{-| Shift the floor a little bit down
-}
floorOffset : { x : Float, y : Float, z : Float }
floorOffset =
    { x = 0, y = 0, z = -1 }


{-| Floor has an empty mesh, because it is not rendered
-}
floor : Body Data
floor =
    { id = Floor, meshes = Meshes.fromTriangles [] }
        |> Body.plane
        |> Body.moveTo (Point3d.fromMeters floorOffset)
        |> Body.withMaterial (Material.custom { friction = 0.1, bounciness = 0.5 })


{-| One of the boxes on the scene
-}
box : Int -> Body Data
box id =
    let
        block3d =
            Block3d.centeredOn
                Frame3d.atOrigin
                ( Length.meters 2
                , Length.meters 2
                , Length.meters 2
                )
    in
    Body.block block3d
        { id = Box id
        , meshes = Meshes.fromTriangles (Meshes.block block3d)
        }
        |> Body.withBehavior (Body.dynamic (Mass.kilograms 10))
        |> Body.withMaterial (Material.custom { friction = 0.1, bounciness = 0.5 })


{-| An empty body with zero mass, rendered as a sphere.
This is a temporary body used to drag selected bodies.
-}
mouse : Body Data
mouse =
    let
        sphere3d =
            Sphere3d.atOrigin (Length.meters 0.2)
    in
    Body.compound []
        { id = Mouse
        , meshes = Meshes.fromTriangles (Meshes.sphere 2 sphere3d)
        }
