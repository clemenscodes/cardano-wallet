-- |
-- Copyright: © 2024 Cardano Foundation
-- License: Apache-2.0
--
module Cardano.Write.Eras
    (
    -- * Eras
      BabbageEra
    , ConwayEra

    -- ** RecentEra
    , RecentEra (..)
    , IsRecentEra (..)
    , CardanoApiEra
    , MaybeInRecentEra (..)
    , LatestLedgerEra
    , RecentEraConstraints
    , allRecentEras

    -- ** Existential wrapper
    , AnyRecentEra (..)

    -- ** Helpers for cardano-api compatibility
    , ShelleyLedgerEra
    , cardanoEraFromRecentEra
    , shelleyBasedEraFromRecentEra
    ) where

import Internal.Cardano.Write.Eras
    ( AnyRecentEra (..)
    , BabbageEra
    , CardanoApiEra
    , ConwayEra
    , IsRecentEra (..)
    , LatestLedgerEra
    , MaybeInRecentEra (..)
    , RecentEra (..)
    , RecentEraConstraints
    , ShelleyLedgerEra
    , allRecentEras
    , cardanoEraFromRecentEra
    , shelleyBasedEraFromRecentEra
    )
