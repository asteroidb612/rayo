module Icosahedron exposing (faces, vertices)


type alias Point =
    { x : Float, y : Float, z : Float }



-- Thanks internet http://rbwhitaker.wikidot.com/index-and-vertex-buffers


size =
    3


v0 =
    { x = size * -0.262865, y = size * 0.0, z = size * 0.425325 }


v1 =
    { x = size * 0.262865, y = size * 0.0, z = size * 0.425325 }


v2 =
    { x = size * -0.262865, y = size * 0.0, z = size * -0.425325 }


v3 =
    { x = size * 0.262865, y = size * 0.0, z = size * -0.425325 }


v4 =
    { x = size * 0.0, y = size * 0.425325, z = size * 0.262865 }


v5 =
    { x = size * 0.0, y = size * 0.425325, z = size * -0.262865 }


v6 =
    { x = size * 0.0, y = size * -0.425325, z = size * 0.262865 }


v7 =
    { x = size * 0.0, y = size * -0.425325, z = size * -0.262865 }


v8 =
    { x = size * 0.425325, y = size * 0.262865, z = size * 0.0 }


v9 =
    { x = size * -0.425325, y = size * 0.262865, z = size * 0.0 }


v10 =
    { x = size * 0.425325, y = size * -0.262865, z = size * 0.0 }


v11 =
    { x = size * -0.425325, y = size * -0.262865, z = size * 0.0 }


faces =
    [ ( v0, v6, v1 )
    , ( v0, v11, v6 )
    , ( v1, v4, v0 )
    , ( v1, v8, v4 )
    , ( v1, v10, v8 )
    , ( v2, v5, v3 )
    , ( v2, v9, v5 )
    , ( v2, v11, v9 )
    , ( v3, v7, v2 )
    , ( v3, v10, v7 )
    , ( v4, v8, v5 )
    , ( v4, v9, v0 )
    , ( v5, v8, v3 )
    , ( v5, v9, v4 )
    , ( v6, v10, v1 )
    , ( v6, v11, v7 )
    , ( v7, v10, v6 )
    , ( v7, v11, v2 )
    , ( v8, v10, v3 )
    , ( v9, v11, v0 )
    ]


vertices =
    [ v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11 ]
