{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE TemplateHaskell #-}

module Cardano.Wallet.UI.Deposit.Html.Pages.Page
    ( Page (..)
    , page
    )
where

import Prelude

import Cardano.Wallet.UI.Common.Html.Html
    ( RawHtml (..)
    )
import Cardano.Wallet.UI.Common.Html.Pages.Network
    ( networkH
    )
import Cardano.Wallet.UI.Common.Html.Pages.Settings
    ( settingsPageH
    )
import Cardano.Wallet.UI.Common.Html.Pages.Template.Body
    ( bodyH
    )
import Cardano.Wallet.UI.Common.Html.Pages.Template.Head
    ( PageConfig (..)
    , pageFromBodyH
    )
import Cardano.Wallet.UI.Common.Html.Pages.Template.Navigation
    ( navigationH
    )
import Cardano.Wallet.UI.Deposit.API
    ( aboutPageLink
    , faviconLink
    , networkInfoLink
    , networkPageLink
    , settingsGetLink
    , settingsPageLink
    , sseLink
    , walletPageLink
    )
import Cardano.Wallet.UI.Deposit.Html.Pages.About
    ( aboutH
    )
import Cardano.Wallet.UI.Deposit.Html.Pages.Wallet
    ( WalletPresent
    , walletH
    )
import Cardano.Wallet.UI.Type
    ( WHtml
    , WalletType (..)
    , runWHtml
    )
import Control.Lens.Extras
    ( is
    )
import Control.Lens.TH
    ( makePrisms
    )
import Data.Text
    ( Text
    )
import Lucid
    ( HtmlT
    , renderBS
    )

import qualified Data.ByteString.Lazy.Char8 as BL

data Page
    = About
    | Network
    | Settings
    | Wallet

makePrisms ''Page

page
    :: PageConfig
    -- ^ Page configuration
    -> Page
    -- ^ Current page
    -> (BL.ByteString -> WHtml ())
    -> WalletPresent
    -- ^ If a wallet is present
    -> RawHtml
page c@PageConfig{..} p alert wp = RawHtml
    $ renderBS
    $ runWHtml Deposit
    $ pageFromBodyH faviconLink c
    $ bodyH (headerH prefix p)
    $ case p of
        About -> aboutH
        Network -> networkH sseLink networkInfoLink
        Settings -> settingsPageH sseLink settingsGetLink
        Wallet -> walletH alert wp

headerH :: Text -> Page -> Monad m => HtmlT m ()
headerH prefix p =
    navigationH
        prefix
        [ (is _About p, aboutPageLink, "About")
        , (is _Network p, networkPageLink, "Network")
        , (is _Settings p, settingsPageLink, "Settings")
        , (is _Wallet p, walletPageLink, "Wallet")
        ]
