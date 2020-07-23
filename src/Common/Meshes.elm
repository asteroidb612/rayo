module Common.Meshes exposing
    ( Attributes
    , Meshes
    , block
    , contact
    , edge
    , fromTriangles
    , normal
    , sphere
    )

import Block3d exposing (Block3d)
import Length exposing (Meters, inMeters)
import Math.Vector2 as Vec2 exposing (Vec2, vec2)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Physics.Coordinates exposing (BodyCoordinates)
import Point3d
import Sphere3d exposing (Sphere3d)
import WebGL exposing (Mesh)


type alias Attributes =
    { position : Vec3
    , normal : Vec3
    , coords : Vec2
    }



-- Meshes


normal : Mesh Attributes
normal =
    toMesh (pyramid 0.05 0.05)


edge : Mesh Attributes
edge =
    toMesh (pyramid 0.1 0.5)


contact : Mesh Attributes
contact =
    toMesh (sphere 2 (Sphere3d.atOrigin (Length.meters 0.07)))


toMesh : List ( Attributes, Attributes, Attributes ) -> Mesh Attributes
toMesh =
    WebGL.triangles


toWireframe : List ( Attributes, Attributes, Attributes ) -> Mesh Attributes
toWireframe =
    trianglesToLines >> WebGL.lines


type alias Meshes =
    { mesh : Mesh Attributes
    , wireframe : Mesh Attributes
    }


fromTriangles : List ( Attributes, Attributes, Attributes ) -> Meshes
fromTriangles triangles =
    { mesh = toMesh triangles
    , wireframe = toWireframe triangles
    }


trianglesToLines : List ( Attributes, Attributes, Attributes ) -> List ( Attributes, Attributes )
trianglesToLines triangles =
    List.foldl
        (\( p1, p2, p3 ) result -> ( p1, p2 ) :: ( p2, p3 ) :: ( p3, p1 ) :: result)
        []
        triangles


block : Block3d Meters BodyCoordinates -> List ( Attributes, Attributes, Attributes )
block block3d =
    let
        ( sizeX, sizeY, sizeZ ) =
            Block3d.dimensions block3d

        blockFrame3d =
            Block3d.axes block3d

        x =
            inMeters sizeX * 0.5

        y =
            inMeters sizeY * 0.5

        z =
            inMeters sizeZ * 0.5

        transform px py pz =
            Point3d.placeIn blockFrame3d (Point3d.meters px py pz)
                |> Point3d.toMeters
                |> Vec3.fromRecord

        v0 =
            transform -x -y -z

        v1 =
            transform x -y -z

        v2 =
            transform x y -z

        v3 =
            transform -x y -z

        v4 =
            transform -x -y z

        v5 =
            transform x -y z

        v6 =
            transform x y z

        v7 =
            transform -x y z
    in
    [ facet v3 v2 v1 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v1 v0 v3 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v4 v5 v6 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v6 v7 v4 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v5 v4 v0 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v0 v1 v5 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v2 v3 v7 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v7 v6 v2 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v0 v4 v7 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v7 v3 v0 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v1 v2 v6 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet v6 v5 v1 (vec2 0 1) (vec2 1 0) (vec2 0 0)
    ]


pyramid : Float -> Float -> List ( Attributes, Attributes, Attributes )
pyramid halfbase baserise =
    let
        top =
            vec3 0 0 1

        rbb =
            vec3 halfbase -halfbase baserise

        rfb =
            vec3 halfbase halfbase baserise

        lfb =
            vec3 -halfbase halfbase baserise

        lbb =
            vec3 -halfbase -halfbase baserise
    in
    [ facet rfb lfb lbb (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet lbb rbb rfb (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet top rfb rbb (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet top lfb rfb (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet top lbb lfb (vec2 0 1) (vec2 1 0) (vec2 0 0)
    , facet top rbb lbb (vec2 0 1) (vec2 1 0) (vec2 0 0)
    ]


sphere : Int -> Sphere3d Meters BodyCoordinates -> List ( Attributes, Attributes, Attributes )
sphere iterations sphere3d =
    let
        position p =
            Point3d.toMeters (Sphere3d.centerPoint sphere3d)
                |> Vec3.fromRecord
                |> Vec3.add p

        radius =
            Length.inMeters (Sphere3d.radius sphere3d)
    in
    divideSphere iterations radius (octahedron radius)
        |> List.map
            (\( p1, p2, p3 ) ->
                facet (position p1) (position p2) (position p3) (vec2 0 0) (vec2 0 0) (vec2 0 0)
            )


{-| Recursively divide an octahedron to turn it into a sphere
-}
divideSphere : Int -> Float -> List ( Vec3, Vec3, Vec3 ) -> List ( Vec3, Vec3, Vec3 )
divideSphere step radius triangles =
    if step == 0 then
        triangles

    else
        triangles
            |> List.foldl (divide radius) []
            |> divideSphere (step - 1) radius


{-|

        1
       / \
    b /___\ c
     /\   /\
    /__\ /__\
    0   a    2

-}
divide : Float -> ( Vec3, Vec3, Vec3 ) -> List ( Vec3, Vec3, Vec3 ) -> List ( Vec3, Vec3, Vec3 )
divide radius ( v0, v1, v2 ) result =
    let
        a =
            Vec3.add v0 v2 |> Vec3.normalize |> Vec3.scale radius

        b =
            Vec3.add v0 v1 |> Vec3.normalize |> Vec3.scale radius

        c =
            Vec3.add v1 v2 |> Vec3.normalize |> Vec3.scale radius
    in
    ( v0, b, a ) :: ( b, v1, c ) :: ( a, b, c ) :: ( a, c, v2 ) :: result


{-| Octahedron
-}
octahedron : Float -> List ( Vec3, Vec3, Vec3 )
octahedron radius =
    [ ( vec3 radius 0 0, vec3 0 radius 0, vec3 0 0 radius )
    , ( vec3 0 radius 0, vec3 -radius 0 0, vec3 0 0 radius )
    , ( vec3 -radius 0 0, vec3 0 -radius 0, vec3 0 0 radius )
    , ( vec3 0 -radius 0, vec3 radius 0 0, vec3 0 0 radius )
    , ( vec3 radius 0 0, vec3 0 0 -radius, vec3 0 radius 0 )
    , ( vec3 0 radius 0, vec3 0 0 -radius, vec3 -radius 0 0 )
    , ( vec3 -radius 0 0, vec3 0 0 -radius, vec3 0 -radius 0 )
    , ( vec3 0 -radius 0, vec3 0 0 -radius, vec3 radius 0 0 )
    ]


facet : Vec3 -> Vec3 -> Vec3 -> Vec2 -> Vec2 -> Vec2 -> ( Attributes, Attributes, Attributes )
facet a b c a_coords b_coords c_coords =
    let
        n =
            Vec3.cross (Vec3.sub b a) (Vec3.sub b c)
    in
    ( Attributes a n a_coords
    , Attributes b n b_coords
    , Attributes c n c_coords
    )