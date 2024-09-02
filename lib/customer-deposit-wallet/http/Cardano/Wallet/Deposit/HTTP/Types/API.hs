{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
-- |
-- Copyright: © 2024 Cardano Foundation
-- License: Apache-2.0
--
-- Servant Type for our HTTP API.
--
module Cardano.Wallet.Deposit.HTTP.Types.API
    ( CustomerAPI
    , NetworkAPI
    )
    where

import Cardano.Wallet.Deposit.HTTP.Types.JSON
    ( Address
    , ApiT
    , ChainPoint
    , Customer
    , CustomerList
    )
import Servant.API
    ( Capture
    , JSON
    , StdMethod (..)
    , Verb
    , (:<|>)
    , (:>)
    )

{-----------------------------------------------------------------------------
    API
------------------------------------------------------------------------------}

type CustomerAPI =
        "customers"
            :> Verb 'GET 200 '[JSON] (ApiT CustomerList)
    :<|>
        "customers"
            :> Capture "customerId" (ApiT Customer)
            :> Verb 'PUT 200 '[JSON] (ApiT Address)

type NetworkAPI =
        "network" :> "local-tip"
            :> Verb 'GET 200 '[JSON] (ApiT ChainPoint)
