port module Main exposing (main)

import Browser
import Html


type Msg
    = NewNumber Int


main : Program () Int Msg
main =
    Browser.element
        { subscriptions = \_ -> changes NewNumber
        , init = \_ -> ( 0, Cmd.none )
        , update =
            \msg model ->
                case msg of
                    NewNumber i ->
                        ( i, Cmd.none )
        , view = \model -> Html.text <| String.fromInt model
        }


port changes : (Int -> msg) -> Sub msg
