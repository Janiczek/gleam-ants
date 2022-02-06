module Main exposing (main)

import Browser
import Dict exposing (Dict)
import Html exposing (Html)
import Http
import Json.Decode as Decode exposing (Decoder)
import List.Cartesian
import RemoteData exposing (RemoteData(..), WebData)
import Svg exposing (Svg)
import Svg.Attributes as SvgAttrs
import Time


main : Program () Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Model =
    WebData Board


type Msg
    = Tick
    | GotBoard (WebData Board)


subscriptions : Model -> Sub Msg
subscriptions model =
    let
        tick =
            Time.every 40 (\_ -> Tick)
    in
    case model of
        Loading ->
            Sub.none

        Failure _ ->
            Sub.none

        NotAsked ->
            tick

        Success _ ->
            tick


init : () -> ( Model, Cmd Msg )
init () =
    ( Loading
    , askForBoard
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick ->
            ( model, askForBoard )

        GotBoard webdata ->
            ( webdata, Cmd.none )


askForBoard : Cmd Msg
askForBoard =
    Http.get
        { url = "http://localhost:3000"
        , expect =
            Http.expectJson
                (RemoteData.fromResult >> GotBoard)
                boardDecoder
        }


type alias Board =
    { size : Int
    , cells : Dict Position Cell
    , ants : Dict Position Ant
    }


type alias Position =
    ( Int, Int )


type alias Cell =
    { isHome : Bool
    , food : Int
    , pheromone : Float
    }


type alias Ant =
    { status : AntStatus
    , direction : Direction
    }


type AntStatus
    = AntWithFood
    | AntWithoutFood


type Direction
    = N
    | NE
    | E
    | SE
    | S
    | SW
    | W
    | NW


boardDecoder : Decoder Board
boardDecoder =
    Decode.map3 Board
        (Decode.field "size" Decode.int)
        (Decode.field "cells" (dictDecoder positionDecoder cellDecoder))
        (Decode.field "ants" (dictDecoder positionDecoder antDecoder))


dictDecoder : Decoder comparable -> Decoder v -> Decoder (Dict comparable v)
dictDecoder keyDecoder valueDecoder =
    Decode.list
        (Decode.map2 Tuple.pair
            (Decode.index 0 keyDecoder)
            (Decode.index 1 valueDecoder)
        )
        |> Decode.map Dict.fromList


positionDecoder : Decoder Position
positionDecoder =
    Decode.map2 Tuple.pair
        (Decode.index 0 Decode.int)
        (Decode.index 1 Decode.int)


cellDecoder : Decoder Cell
cellDecoder =
    Decode.map3 Cell
        (Decode.field "is_home" Decode.bool)
        (Decode.field "food" Decode.int)
        (Decode.field "pheromone" Decode.float)


antDecoder : Decoder Ant
antDecoder =
    Decode.map2 Ant
        (Decode.field "status" antStatusDecoder)
        (Decode.field "direction" directionDecoder)


antStatusDecoder : Decoder AntStatus
antStatusDecoder =
    Decode.string
        |> Decode.andThen
            (\status ->
                case status of
                    "with-food" ->
                        Decode.succeed AntWithFood

                    "without-food" ->
                        Decode.succeed AntWithoutFood

                    _ ->
                        Decode.fail <| "Unknown ant status: '" ++ status ++ "'"
            )


directionDecoder : Decoder Direction
directionDecoder =
    Decode.string
        |> Decode.andThen
            (\dir ->
                case dir of
                    "n" ->
                        Decode.succeed N

                    "ne" ->
                        Decode.succeed NE

                    "e" ->
                        Decode.succeed E

                    "se" ->
                        Decode.succeed SE

                    "s" ->
                        Decode.succeed S

                    "sw" ->
                        Decode.succeed SW

                    "w" ->
                        Decode.succeed W

                    "nw" ->
                        Decode.succeed NW

                    _ ->
                        Decode.fail <| "Unknown direction: '" ++ dir ++ "'"
            )


view : Model -> Html Msg
view model =
    case model of
        NotAsked ->
            Html.text "Bug: didn't ask for the board state"

        Loading ->
            Html.text "Loading..."

        Failure err ->
            Html.text <| "Error: " ++ Debug.toString err

        Success board ->
            viewBoard board


viewBoard : Board -> Html Msg
viewBoard board =
    let
        cellSize : Float
        cellSize =
            10

        halfCellSize : Float
        halfCellSize =
            cellSize / 2

        cellSizeStr =
            String.fromFloat cellSize

        boardSizeStr =
            String.fromFloat <| toFloat board.size * cellSize

        maxFoodCount : Float
        maxFoodCount =
            -- TODO get this from the backend?
            100

        maxPheromoneAmount : Float
        maxPheromoneAmount =
            50

        grid : List (Svg Msg)
        grid =
            [ Svg.defs []
                [ Svg.pattern
                    [ SvgAttrs.id "grid"
                    , SvgAttrs.width cellSizeStr
                    , SvgAttrs.height cellSizeStr
                    , SvgAttrs.patternUnits "userSpaceOnUse"
                    ]
                    [ Svg.path
                        [ SvgAttrs.d <| "M " ++ cellSizeStr ++ " 0 L 0 0 0 " ++ cellSizeStr
                        , SvgAttrs.fill "none"
                        , SvgAttrs.stroke "gray"
                        , SvgAttrs.strokeWidth "0.5"
                        ]
                        []
                    ]
                ]
            , Svg.rect
                [ SvgAttrs.width "100%"
                , SvgAttrs.height "100%"
                , SvgAttrs.fill "url(#grid)"
                ]
                []
            ]

        cells : List (Svg Msg)
        cells =
            List.Cartesian.map2 Tuple.pair
                (List.range 0 (board.size - 1))
                (List.range 0 (board.size - 1))
                |> List.map
                    (\(( x, y ) as position) ->
                        let
                            ant : Maybe Ant
                            ant =
                                Dict.get position board.ants

                            cell : Cell
                            cell =
                                Dict.get position board.cells
                                    |> Maybe.withDefault (Cell False 0 0)

                            ( svgX, svgY ) =
                                ( toFloat x * cellSize
                                , toFloat y * cellSize
                                )

                            middleOf coord =
                                coord + halfCellSize

                            ( fillColor, opacity ) =
                                if cell.isHome then
                                    ( "#fffbeb", 1 )

                                else if cell.food > 0 then
                                    ( "#65a30d", min 1 <| toFloat cell.food / maxFoodCount )

                                else if cell.pheromone > 0 then
                                    ( "#d946ef", min 1 <| cell.pheromone / maxPheromoneAmount )

                                else
                                    ( "none", 0 )

                            cellView =
                                Svg.rect
                                    [ SvgAttrs.width cellSizeStr
                                    , SvgAttrs.height cellSizeStr
                                    , SvgAttrs.x <| String.fromFloat svgX
                                    , SvgAttrs.y <| String.fromFloat svgY
                                    , SvgAttrs.fill fillColor
                                    , SvgAttrs.opacity <| String.fromFloat opacity
                                    ]
                                    []

                            antDirectionView =
                                case ant of
                                    Nothing ->
                                        Html.text ""

                                    Just { direction } ->
                                        let
                                            width =
                                                2 / 10 * cellSize

                                            height =
                                                6 / 10 * cellSize

                                            centerX =
                                                middleOf svgX

                                            centerY =
                                                middleOf svgY
                                        in
                                        Svg.rect
                                            [ SvgAttrs.x <| String.fromFloat <| centerX - width / 2
                                            , SvgAttrs.y <| String.fromFloat <| centerY - height
                                            , SvgAttrs.width <| String.fromFloat width
                                            , SvgAttrs.height <| String.fromFloat height
                                            , SvgAttrs.fill "black"
                                            , SvgAttrs.transform <|
                                                "rotate("
                                                    ++ String.fromFloat (directionDegrees direction)
                                                    ++ " "
                                                    ++ String.fromFloat centerX
                                                    ++ " "
                                                    ++ String.fromFloat centerY
                                                    ++ ")"
                                            ]
                                            []

                            antFoodView =
                                case ant of
                                    Nothing ->
                                        Html.text ""

                                    Just { status } ->
                                        let
                                            ( fill, stroke ) =
                                                case status of
                                                    AntWithoutFood ->
                                                        ( "none", "#84cc16" )

                                                    AntWithFood ->
                                                        ( "#84cc16", "none" )
                                        in
                                        Svg.circle
                                            [ SvgAttrs.r <| String.fromFloat <| 3 / 10 * cellSize
                                            , SvgAttrs.cx <| String.fromFloat <| middleOf svgX
                                            , SvgAttrs.cy <| String.fromFloat <| middleOf svgY
                                            , SvgAttrs.fill fill
                                            , SvgAttrs.stroke stroke
                                            ]
                                            []
                        in
                        Svg.g []
                            [ cellView
                            , antFoodView
                            , antDirectionView
                            ]
                    )
    in
    Svg.svg
        [ SvgAttrs.width boardSizeStr
        , SvgAttrs.height boardSizeStr
        , SvgAttrs.viewBox <| "0 0 " ++ boardSizeStr ++ " " ++ boardSizeStr
        ]
        (cells ++ grid)


directionDegrees : Direction -> Float
directionDegrees dir =
    (case dir of
        N ->
            0 / 8

        NE ->
            1 / 8

        E ->
            2 / 8

        SE ->
            3 / 8

        S ->
            4 / 8

        SW ->
            5 / 8

        W ->
            6 / 8

        NW ->
            7 / 8
    )
        |> turns
        |> (*) (180 / pi)
