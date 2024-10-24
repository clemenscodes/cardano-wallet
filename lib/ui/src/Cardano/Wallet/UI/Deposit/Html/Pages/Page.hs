{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE RankNTypes #-}

module Cardano.Wallet.UI.Deposit.Html.Pages.Page
    ( Page (..)
    , page
    , headerElementH
    )
where

import Prelude

import Cardano.Wallet.UI.Common.Html.Html
    ( RawHtml (..)
    )
import Cardano.Wallet.UI.Common.Html.Lib
    ( imageOverlay
    )
import Cardano.Wallet.UI.Common.Html.Modal
    ( modalsH
    )
import Cardano.Wallet.UI.Common.Html.Pages.Lib
    ( sseH
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
    ( Page (..)
    , aboutPageLink
    , addressesPageLink
    , faviconLink
    , navigationLink
    , networkInfoLink
    , networkPageLink
    , settingsGetLink
    , settingsPageLink
    , sseLink
    , walletPageLink
    , _About
    , _Addresses
    , _Network
    , _Settings
    , _Wallet
    )
import Cardano.Wallet.UI.Deposit.Html.Pages.About
    ( aboutH
    )
import Cardano.Wallet.UI.Deposit.Html.Pages.Addresses
    ( addressesH
    )
import Cardano.Wallet.UI.Deposit.Html.Pages.Wallet
    ( WalletPresent
    , isPresent
    , walletH
    )
import Cardano.Wallet.UI.Type
    ( WalletType (..)
    , runWHtml
    )
import Control.Lens
    ( _Just
    )
import Control.Lens.Extras
    ( is
    )
import Lucid
    ( HtmlT
    , renderBS
    )

page
    :: PageConfig
    -- ^ Page configuration
    -> Page
    -- ^ Current page
    -> RawHtml
page c p = RawHtml
    $ renderBS
    $ runWHtml Deposit
    $ pageFromBodyH faviconLink c
    $ do
        bodyH sseLink (headerH p)
            $ do
                modalsH
                imageOverlay
                case p of
                    About -> aboutH
                    Network -> networkH networkInfoLink
                    Settings -> settingsPageH settingsGetLink
                    Wallet -> walletH
                    Addresses -> addressesH

headerH :: Monad m => Page -> HtmlT m ()
headerH p = sseH (navigationLink $ Just p) "header" ["wallet"]

headerElementH :: Maybe Page -> WalletPresent -> Monad m => HtmlT m ()
headerElementH p wp =
    navigationH
        mempty
        $ [(is' _Wallet, walletPageLink, "Wallet")]
            <> [ (is' _Addresses, addressesPageLink, "Addresses")
               | isPresent wp
               ]
            <> [ (is' _Network, networkPageLink, "Network")
               , (is' _Settings, settingsPageLink, "Settings")
               , (is' _About, aboutPageLink, "About")
               ]
  where
    is' l = is (_Just . l) p
