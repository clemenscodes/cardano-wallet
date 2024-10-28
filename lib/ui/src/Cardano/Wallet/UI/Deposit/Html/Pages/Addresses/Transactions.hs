{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE PatternSynonyms #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Cardano.Wallet.UI.Deposit.Html.Pages.Addresses.Transactions
where

import Prelude

import Cardano.Wallet.Deposit.Pure
    ( ValueTransfer
    , received
    , spent
    )
import Cardano.Wallet.UI.Common.Html.Lib
    ( linkText
    , overlayFakeDataH
    , tdEnd
    , thEnd
    )
import Cardano.Wallet.UI.Common.Html.Pages.Lib
    ( Striped (..)
    , Width (..)
    , box
    , record
    , simpleField
    )
import Cardano.Wallet.UI.Deposit.API
    ( TransactionHistoryParams (..)
    , customerHistoryLink
    , fakeDataBackgroundLink
    )
import Control.Monad
    ( forM_
    , when
    )
import Lucid
    ( Html
    , HtmlT
    , ToHtml (..)
    , button_
    , checked_
    , class_
    , data_
    , div_
    , i_
    , id_
    , input_
    , name_
    , option_
    , scope_
    , select_
    , selected_
    , span_
    , style_
    , table_
    , tbody_
    , thead_
    , tr_
    , type_
    , value_
    )

import Cardano.Wallet.Deposit.Read
    ( Slot
    , TxId
    , WithOrigin
    )
import Cardano.Wallet.UI.Common.Html.Htmx
    ( hxInclude_
    , hxPost_
    , hxTarget_
    , hxTrigger_
    )
import Cardano.Wallet.UI.Deposit.Html.Common
    ( slotH
    , timeH
    , txIdH
    , withOriginH
    )
import Data.Text
    ( Text
    )
import Data.Time
    ( UTCTime (..)
    , pattern YearMonthDay
    )
import Numeric
    ( showFFloatAlt
    )

import qualified Cardano.Wallet.Read as Read
import qualified Data.Text.Class as T

chainPointToSlotH
    :: Read.ChainPoint
    -> Html ()
chainPointToSlotH cp = case cp of
    Read.GenesisPoint -> toHtml ("Genesis" :: Text)
    Read.BlockPoint (Read.SlotNo n) _ -> toHtml $ show n

valueH :: Read.Value -> Html ()
valueH (Read.ValueC (Read.CoinC c) _) = do
    span_ $ toHtml $ a ""
    span_ [class_ "opacity-25"] "₳"
  where
    a = showFFloatAlt @Double (Just 2) $ fromIntegral c / 1_000_000

txSummaryH
    :: TransactionHistoryParams
    -> (WithOrigin UTCTime, (Slot, TxId, ValueTransfer))
    -> Html ()
txSummaryH
    TransactionHistoryParams{..}
    (time, (slot, txId, value)) = do
        tr_ [scope_ "row"] $ do
            when txHistorySlot
                $ tdEnd
                $ slotH slot
            when txHistoryUTC
                $ tdEnd
                $ withOriginH timeH time
            when txHistoryReceived
                $ tdEnd
                $ valueH
                $ received value
            when txHistorySpent
                $ tdEnd
                $ valueH
                $ spent value
            tdEnd $ txIdH txId

customerHistoryH
    :: Monad m
    => Bool
    -> TransactionHistoryParams
    -> [(WithOrigin UTCTime,(Slot, TxId, ValueTransfer))]
    -> HtmlT m ()
customerHistoryH fake params@TransactionHistoryParams{..} txs =
    fakeOverlay $ do
        table_
            [ class_
                $ "border-top table table-striped table-hover m-0"
                    <> if fake then " fake" else ""
            ]
            $ do
                thead_
                    $ tr_
                        [ scope_ "row"
                        , class_ "sticky-top my-1"
                        , style_ "z-index: 1"
                        ]
                    $ do
                        when txHistorySlot
                            $ thEnd (Just 7) "Slot"
                        when txHistoryUTC
                            $ thEnd (Just 9) "Time"
                        when txHistoryReceived
                            $ thEnd (Just 7) "Deposit"
                        when txHistorySpent
                            $ thEnd (Just 7) "Withdrawal"
                        thEnd Nothing "Id"
                tbody_
                    $ mapM_ (toHtml . txSummaryH params) txs
  where
    fakeOverlay = if fake then overlayFakeDataH fakeDataBackgroundLink else id

yearOf :: UTCTime -> Integer
yearOf UTCTime{utctDay = YearMonthDay year _ _} = year

monthOf :: UTCTime -> Int
monthOf UTCTime{utctDay = YearMonthDay _ month _} = month

monthsH :: UTCTime -> Html ()
monthsH now = do
    select_
        [ class_ "form-select w-auto m-1 p-1"
        , id_ "select-month"
        , name_ "start-month"
        , style_ "background-image: none"
        ]
        $ forM_ [1 .. 12]
        $ \month -> do
            let select =
                    if month == monthOf now
                        then ([selected_ ""] <>)
                        else id
            option_ (select [value_ $ T.toText month])
                $ toHtml
                $ T.toText month

yearsH :: UTCTime -> UTCTime -> Html ()
yearsH now origin = do
    let firstYear = yearOf origin
        lastYear = yearOf now
    select_
        [ class_ "form-select w-auto m-1 p-1"
        , id_ "select-year"
        , name_ "start-year"
        , style_ "background-image: none"
        ]
        $ forM_ [firstYear .. lastYear]
        $ \year -> do
            let select =
                    if year == lastYear
                        then ([selected_ ""] <>)
                        else id
            option_ (select [value_ $ T.toText year])
                $ toHtml
                $ T.toText year

transactionsViewControls :: UTCTime -> UTCTime -> Html ()
transactionsViewControls now origin =
    div_ [class_ "collapse", id_ "columns-control"] $ do
        record Nothing Auto NotStriped $ do
            simpleField "UTC"
                $ div_
                    [ class_ "d-flex justify-content-end align-items-center form-check"
                    ]
                $ input_
                    [ class_ "form-check-input"
                    , type_ "checkbox"
                    , id_ "toggle-utc"
                    , hxTrigger_ "change"
                    , name_ "utc"
                    , value_ ""
                    , checked_
                    ]
            simpleField "Slot"
                $ div_
                    [ class_ "d-flex justify-content-end align-items-center form-check"
                    ]
                $ input_
                    [ class_ "form-check-input"
                    , type_ "checkbox"
                    , id_ "toggle-slot"
                    , name_ "slot"
                    , value_ ""
                    ]
            simpleField "Deposit"
                $ div_
                    [ class_ "d-flex justify-content-end align-items-center form-check"
                    ]
                $ input_
                    [ class_ "form-check-input"
                    , type_ "checkbox"
                    , id_ "toggle-deposit"
                    , name_ "received"
                    , value_ ""
                    , checked_
                    ]
            simpleField "Withdrawal"
                $ div_
                    [ class_ "d-flex justify-content-end align-items-center form-check"
                    ]
                $ input_
                    [ class_ "form-check-input"
                    , type_ "checkbox"
                    , id_ "toggle-withdrawal"
                    , name_ "spent"
                    , value_ ""
                    ]
            simpleField "Sorting"
                $ div_
                    [ class_ "d-flex justify-content-end align-items-center"
                    ]
                $ select_
                    [ class_ "form-select w-auto m-1 p-1"
                    , id_ "select-sorting"
                    , name_ "sorting"
                    , style_ "background-image: none"
                    ]
                $ do
                    option_ [selected_ "", value_ "desc"] "Descending"
                    option_ [value_ "asc"] "Ascending"
            simpleField "From"
                $ div_
                    [ class_ "d-flex justify-content-end align-items-center"
                    ]
                $ do
                    yearsH now origin
                    monthsH now

transactionsElementH :: UTCTime -> UTCTime -> Html ()
transactionsElementH now origin = do
    div_
        [ class_ "row mt-2 gx-0"
        , hxTrigger_
            "load\
            \, change from:#toggle-utc\
            \, change from:#select-customer\
            \, change from:#toggle-slot\
            \, change from:#toggle-deposit\
            \, change from:#toggle-withdrawal\
            \, change from:#select-sorting\
            \, change from:#select-month\
            \, change from:#select-year"
        , hxInclude_ "#view-control"
        , hxPost_ $ linkText customerHistoryLink
        , hxTarget_ "#transactions"
        ]
        $ do
            let configure =
                    div_ [class_ "d-flex justify-content-end"] $ do
                        let toggle = button_
                                [ class_ "btn"
                                , type_ "button"
                                , data_ "bs-toggle" "collapse"
                                , data_ "bs-target" "#columns-control"
                                ]
                                $ div_
                                $ do
                                    i_ [class_ "bi bi-gear"] mempty
                        box mempty toggle
                            $ transactionsViewControls now origin
            box "Transactions" mempty $ do
                configure
                div_ [class_ "row gx-0"] $ do
                    div_
                        [ class_ "col"
                        , id_ "transactions"
                        ]
                        mempty
