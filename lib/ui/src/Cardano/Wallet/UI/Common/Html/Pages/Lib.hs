{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TypeApplications #-}

module Cardano.Wallet.UI.Common.Html.Pages.Lib
    ( alertH
    , rogerH
    , AssocRow (..)
    , assocRowH
    , record
    , field
    , simpleField
    , fieldHtml
    , fieldShow
    , sseH
    , sseInH
    , adaOfLovelace
    , showAda
    , showAdaOfLoveLace
    , showThousandDots
    , fadeInId
    , Width (..)
    , onWidth
    , Striped (..)
    , onStriped
    , box
    )
where

import Prelude

import Cardano.Wallet.UI.Common.Html.Htmx
    ( hxExt_
    , hxGet_
    , hxSwap_
    , hxTarget_
    , hxTrigger_
    )
import Cardano.Wallet.UI.Common.Html.Lib
    ( linkText
    )
import Cardano.Wallet.UI.Lib.ListOf
    ( Cons (..)
    , ListOf
    , listOf
    )
import Control.Monad.Operational
    ( singleton
    )
import Data.Text
    ( Text
    )
import Lucid
    ( Attribute
    , Html
    , HtmlT
    , ToHtml (..)
    , b_
    , class_
    , div_
    , hr_
    , id_
    , nav_
    , role_
    , scope_
    , style_
    , table_
    , td_
    , tr_
    )
import Lucid.Base
    ( makeAttribute
    )
import Numeric.Natural
    ( Natural
    )
import Servant
    ( Link
    )
import Text.Printf
    ( printf
    )

import qualified Data.Text as T

-- | A simple alert message around any html content.
alertH :: (ToHtml a, Monad m) => a -> HtmlT m ()
alertH =
    div_
        [ id_ "result"
        , class_ "alert alert-primary"
        , role_ "alert"
        ]
        . toHtml

-- | A simple OK message around any html content.
rogerH :: ToHtml a => a -> Html ()
rogerH =
    div_
        [ id_ "result"
        , class_ "alert alert-success"
        , role_ "alert"
        ]
        . toHtml

-- | A simple table row with two columns.
data AssocRow m
    = AssocRow
    { rowAttributes :: [Attribute]
    , key :: HtmlT m ()
    , val :: HtmlT m ()
    }

-- | Render an 'AssocRow' as a table row.
assocRowH :: Maybe Int -> AssocRow m -> Monad m => HtmlT m ()
assocRowH mn AssocRow{..} = tr_ ([scope_ "row"] <> rowAttributes) $ do
    td_ [scope_ "col", class_ "align-bottom p-1", style_ width] $ b_ key
    td_ [scope_ "col", class_ "align-bottom flex-fill p-1"] val
  where
    width = T.pack
        $ case mn of
            Just n -> printf "width: %dem" n
            Nothing -> "width: auto"

data Width = Auto | Full

onWidth :: Width -> a -> a -> a
onWidth w a b = case w of
    Auto -> a
    Full -> b

data Striped = Striped | NotStriped

onStriped :: Striped -> a -> a -> a
onStriped s a b = case s of
    Striped -> a
    NotStriped -> b

-- | Render a list of 'AssocRow' as a table. We use 'listOf' to allow 'do' notation
-- in the definition of the rows
record :: Maybe Int -> Width -> Striped -> ListOf (AssocRow m) -> Monad m => HtmlT m ()
record n w s xs =
    table_
        [ class_ $ "border-top table table-hover mb-0" <> onStriped s " table-striped" ""
        , style_
            $ onWidth w "width: auto" ""
        ]
        $ mapM_ (assocRowH n)
        $ listOf xs

-- | Create an 'AssocRow' from a key and a value.
field :: [Attribute] -> HtmlT m () -> HtmlT m () -> ListOf (AssocRow m)
field attrs key val = singleton $ Elem $ AssocRow attrs key val

-- | Create a simple 'AssocRow' from a key and a value. where the key is a 'Text'.
simpleField :: Monad m => Text -> HtmlT m () -> ListOf (AssocRow m)
simpleField = field [] . toHtml

-- | Create an 'AssocRow' from a key and a value where the value is an 'Html'.
fieldHtml :: Monad m => [Attribute] -> Text -> HtmlT m () -> ListOf (AssocRow m)
fieldHtml as = field as . toHtml

-- | Create an 'AssocRow' from a key and a value where the value is a 'Show' instance.
fieldShow :: (Show a, Monad m) => [Attribute] -> Text -> a -> ListOf (AssocRow m)
fieldShow attrs key val = field attrs (toHtml key) (toHtml $ show val)

fadeInId :: Monad m => HtmlT m ()
fadeInId =
    style_ []
        $ toHtml @Text
            ".smooth.htmx-added { transition: opacity: 0.1s ease-in; opacity: 0} \
            \.smooth { opacity: 1; transition: opacity 0.1s ease-out; }"

-- | A tag that can self populate with data that is fetched as GET from a link
-- whenever some specific events are received from an SSE endpoint.
-- It also self populate on load.
sseH
    :: Link
    -- ^ Link to fetch data from
    -> Text
    -- ^ Target element
    -> [Text]
    -- ^ Events to trigger onto
    -> Monad m
    => HtmlT m ()
sseH link target events = do
    do
        div_
            [ hxTrigger_ triggered
            , hxGet_ $ linkText link
            , hxTarget_ $ "#" <> target
            , hxSwap_ "innerHTML"
            ]
            $ div_
                [ id_ target
                , hxGet_ $ linkText link
                , hxTrigger_ "load"
                , class_ "smooth"
                ]
                ""
  where
    triggered = T.intercalate "," $ ("sse:" <>) <$> events

-- | A tag that can self populate with data directly received in the SSE event.
sseInH :: Text -> [Text] -> Html ()
sseInH target events =
    div_
        [ hxExt_ "sse"
        ]
        $ div_
            [ hxTarget_ $ "#" <> target
            , hxSwap_ "innerHTML"
            , makeAttribute "sse-swap" triggered
            ]
        $ div_ [id_ target] "hello"
  where
    triggered = T.intercalate "," events

-- | Convert a number of lovelace to ADA and lovelace.
adaOfLovelace :: Natural -> (Natural, Natural)
adaOfLovelace x =
    let
        (ada, lovelace) = properFraction @Double $ fromIntegral x / 1_000_000
    in
        (ada, floor $ lovelace * 1_000_000)

-- | Show ADA and lovelace.
showAda :: (Natural, Natural) -> Text
showAda (ada, lovelace) =
    T.pack
        $ showThousandDots ada
            <> ", "
            <> pad 6 (show lovelace)
            <> " ADA"
  where
    pad n s = replicate (n - length s) '0' <> s

-- | Show ADA and lovelace from lovelace.
showAdaOfLoveLace :: Natural -> Text
showAdaOfLoveLace = showAda . adaOfLovelace

-- | Show a number with thousand dots.
showThousandDots :: Show a => a -> String
showThousandDots = reverse . showThousandDots' . reverse . show
  where
    showThousandDots' :: String -> String
    showThousandDots' [] = []
    showThousandDots' xs =
        let
            (a, b) = splitAt 3 xs
        in
            a <> if null b then [] else "." <> showThousandDots' b

box :: Monad m => HtmlT m () -> HtmlT m () -> HtmlT m () -> HtmlT m ()
box x y z = div_ [class_ "bg-body-secondary pb-1"] $ do
    nav_ [class_ "navbar  p-1 justify-content-center pb-0"]
        $ do
            div_ [class_ "navbar-brand opacity-50 ms-1 m-0 container-fluid p-0"] $ do
                div_ x
                div_ y
    hr_ [class_ "mt-0 mb-1"]
    div_ [class_ "bg-body-primary"] z
