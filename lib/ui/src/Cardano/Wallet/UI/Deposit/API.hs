{-# LANGUAGE BlockArguments #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE PolyKinds #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE TypeOperators #-}
{-# OPTIONS_GHC -Wno-orphans #-}

module Cardano.Wallet.UI.Deposit.API where

import Prelude

import Cardano.Wallet.Deposit.Pure
    ( Customer
    )
import Cardano.Wallet.Deposit.REST.Wallet.Create
    ( PostWalletViaMenmonic
    , PostWalletViaXPub
    )
import Cardano.Wallet.UI.Common.API
    ( Image
    , SessionedHtml
    , type (|>)
    , type (|>>)
    )
import Cardano.Wallet.UI.Common.Handlers.SSE
    ( SSE
    )
import Cardano.Wallet.UI.Cookies
    ( CookieRequest
    )
import Control.Lens
    ( makePrisms
    )
import Servant
    ( Delete
    , FormUrlEncoded
    , FromHttpApiData (..)
    , Get
    , Link
    , Post
    , Proxy (..)
    , QueryParam
    , ReqBody
    , ToHttpApiData (..)
    , allLinks
    , (:<|>) (..)
    , (:>)
    )
import Web.FormUrlEncoded
    ( FromForm (..)
    , lookupMaybe
    , parseUnique
    )

import Cardano.Wallet.Read
    ( SlotNo (..)
    , WithOrigin (..)
    )
import Cardano.Wallet.UI.Lib.Time.Direction
    ( Direction (..)
    )
import Data.Maybe
    ( isJust
    )

import qualified Data.ByteString.Lazy as BL

instance FromForm PostWalletViaMenmonic

instance FromForm PostWalletViaXPub

data Page
    = About
    | Network
    | Settings
    | Wallet
    | Addresses

makePrisms ''Page

instance ToHttpApiData Page where
    toUrlPiece About = "about"
    toUrlPiece Network = "network"
    toUrlPiece Settings = "settings"
    toUrlPiece Wallet = "wallet"
    toUrlPiece Addresses = "addresses"

instance FromHttpApiData Page where
    parseUrlPiece "about" = Right About
    parseUrlPiece "network" = Right Network
    parseUrlPiece "settings" = Right Settings
    parseUrlPiece "wallet" = Right Wallet
    parseUrlPiece "addresses" = Right Addresses
    parseUrlPiece _ = Left "Invalid page"

-- | Pages endpoints
type Pages =
    "about" :> SessionedHtml Get
        :<|> "network" :> SessionedHtml Get
        :<|> "settings" :> SessionedHtml Get
        :<|> "wallet" :> SessionedHtml Get
        :<|> "addresses" :> SessionedHtml Get

-- | Data endpoints
type Data =
    "network" :> "info" :> SessionedHtml Get
        :<|> "settings" :> SessionedHtml Get
        :<|> "settings" :> "sse" :> "toggle" :> SessionedHtml Post
        :<|> "sse" :> (CookieRequest :> SSE)
        :<|> "favicon.ico" :> Get '[Image] BL.ByteString
        :<|> "images"
            :> "fake-data.png"
            :> Get '[Image] BL.ByteString
        :<|> "wallet"
            :> "mnemonic"
            :> QueryParam "clean" Bool
            :> SessionedHtml Get
        :<|> "wallet" :> SessionedHtml Get
        :<|> "wallet"
            :> "mnemonic"
            :> ReqBody '[FormUrlEncoded] PostWalletViaMenmonic
            :> SessionedHtml Post
        :<|> "wallet"
            :> "xpub"
            :> ReqBody '[FormUrlEncoded] PostWalletViaXPub
            :> SessionedHtml Post
        :<|> "wallet" :> SessionedHtml Delete
        :<|> "wallet" :> "delete" :> "modal" :> SessionedHtml Get
        :<|> "customer"
            :> "address"
            :> ReqBody '[FormUrlEncoded] Customer
            :> SessionedHtml Post
        :<|> "addresses" :> SessionedHtml Get
        :<|> "navigation" :> QueryParam "page" Page :> SessionedHtml Get
        :<|> "customer"
            :> "transactions"
            :> "history"
            :> ReqBody '[FormUrlEncoded] TransactionHistoryParams
            :> SessionedHtml Post

instance FromHttpApiData Direction where
    parseUrlPiece "asc" = Right Asc
    parseUrlPiece "desc" = Right Desc
    parseUrlPiece _ = Left "Invalid sorting direction"

data TransactionHistoryParams = TransactionHistoryParams
    { txHistoryCustomer :: Customer
    , txHistoryUTC :: Bool
    , txHistorySlot :: Bool
    , txHistorySpent :: Bool
    , txHistoryReceived :: Bool
    , txHistorySorting :: Direction
    , txHistoryStartYear :: Int
    , txHistoryStartMonth :: Int
    }

instance FromForm Customer where
    fromForm form = fromIntegral @Int <$> parseUnique "customer" form

instance FromForm TransactionHistoryParams where
    fromForm form = do
        utc <- isJust <$> lookupMaybe "utc" form
        customer <- fromIntegral @Int <$> parseUnique "customer" form
        slot <- isJust <$> lookupMaybe "slot" form
        spent <- isJust <$> lookupMaybe "spent" form
        received <- isJust <$> lookupMaybe "received" form
        sorting <- parseUnique "sorting" form
        year <- parseUnique "start-year" form
        month <- parseUnique "start-month" form
        pure
            $ TransactionHistoryParams
                customer
                utc
                slot
                spent
                received
                sorting
                year
                month

instance FromHttpApiData SlotNo where
    parseUrlPiece = fmap SlotNo . parseUrlPiece

instance FromHttpApiData t => FromHttpApiData (WithOrigin t) where
    parseUrlPiece "Origin" = pure Origin
    parseUrlPiece t = At <$> parseUrlPiece t

instance ToHttpApiData SlotNo where
    toUrlPiece (SlotNo t) = toUrlPiece t

instance ToHttpApiData t => ToHttpApiData (WithOrigin t) where
    toUrlPiece Origin = "Origin"
    toUrlPiece (At t) = toUrlPiece t

type Home = SessionedHtml Get

-- | UI endpoints
type UI =
    Home
        :<|> "page"
            |> Pages
            |>> "data"
            |> Data

homePageLink :: Link
aboutPageLink :: Link
networkPageLink :: Link
settingsPageLink :: Link
walletPageLink :: Link
addressesPageLink :: Link
networkInfoLink :: Link
settingsGetLink :: Link
settingsSseToggleLink :: Link
sseLink :: Link
faviconLink :: Link
fakeDataBackgroundLink :: Link
walletMnemonicLink :: Maybe Bool -> Link
walletLink :: Link
walletPostMnemonicLink :: Link
walletPostXPubLink :: Link
walletDeleteLink :: Link
walletDeleteModalLink :: Link
customerAddressLink :: Link
addressesLink :: Link
navigationLink :: Maybe Page -> Link
customerHistoryLink :: Link
homePageLink
    :<|> aboutPageLink
    :<|> networkPageLink
    :<|> settingsPageLink
    :<|> walletPageLink
    :<|> addressesPageLink
    :<|> networkInfoLink
    :<|> settingsGetLink
    :<|> settingsSseToggleLink
    :<|> sseLink
    :<|> faviconLink
    :<|> fakeDataBackgroundLink
    :<|> walletMnemonicLink
    :<|> walletLink
    :<|> walletPostMnemonicLink
    :<|> walletPostXPubLink
    :<|> walletDeleteLink
    :<|> walletDeleteModalLink
    :<|> customerAddressLink
    :<|> addressesLink
    :<|> navigationLink
    :<|> customerHistoryLink =
        allLinks (Proxy @UI)
