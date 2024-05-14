{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE QuasiQuotes #-}
{-# OPTIONS_GHC -Wno-unused-top-binds #-}

module Cardano.Wallet.Launch.Cluster.Http.Monitor.APISpec
    ( spec
    , genObservation
    , genMonitorState
    )
where

import Prelude

import Cardano.Launcher.Node
    ( CardanoNodeConn
    , cardanoNodeConn
    )
import Cardano.Ledger.Shelley.Genesis
    ( ShelleyGenesis
    )
import Cardano.Wallet.Launch.Cluster
    ( RunningNode (..)
    )
import Cardano.Wallet.Launch.Cluster.Http.Monitor.API
    ( ApiT (..)
    )
import Cardano.Wallet.Launch.Cluster.Monitoring.Phase
    ( History (..)
    , Phase (..)
    )
import Cardano.Wallet.Primitive.Ledger.Shelley
    ( StandardCrypto
    )
import Control.Monitoring.Tracing
    ( MonitorState (..)
    )
import Data.Aeson
    ( FromJSON (..)
    , Result (..)
    , ToJSON (..)
    , Value
    , fromJSON
    )
import Data.Aeson.QQ
    ( aesonQQ
    )
import Data.OpenApi
    ( ToSchema
    , validateToJSON
    )
import Data.Time
    ( Day (ModifiedJulianDay)
    , UTCTime (UTCTime)
    , secondsToDiffTime
    )
import Ouroboros.Network.Magic
    ( NetworkMagic (..)
    )
import Ouroboros.Network.NodeToClient
    ( NodeToClientVersionData (..)
    )
import Test.Hspec
    ( Expectation
    , Spec
    , describe
    , it
    , shouldBe
    )
import Test.QuickCheck
    ( Arbitrary (..)
    , Gen
    , forAll
    , listOf
    , oneof
    )

jsonRoundtrip :: (ToJSON a, FromJSON a, Eq a, Show a) => a -> IO ()
jsonRoundtrip a = fromJSON (toJSON a) `shouldBe` Success a

validate :: (ToJSON t, ToSchema t) => t -> Expectation
validate x = validateToJSON x `shouldBe` []

spec :: Spec
spec = do
    describe "observe endpoint" $ do
        it "json response roundtrips"
            $ forAll genObservation
            $ jsonRoundtrip . ApiT
        it "json response schema validates random data"
            $ forAll genObservation
            $ validate . ApiT
    describe "switch endpoint" $ do
        it "json response roundtrips"
            $ forAll genMonitorState
            $ jsonRoundtrip . ApiT
        it "json response validates random data"
            $ forAll genMonitorState
            $ validate . ApiT

genObservation :: Gen (History, MonitorState)
genObservation = do
    history' <-
        History <$> listOf ((,) <$> genUTCTime <*> genPhase)
    state <- genMonitorState
    pure (history', state)

genMonitorState :: Gen MonitorState
genMonitorState = oneof [pure Wait, pure Step, pure Run]

genUTCTime :: Gen UTCTime
genUTCTime = do
    day <- ModifiedJulianDay <$> arbitrary
    seconds <- secondsToDiffTime . (`mod` (3600 * 24)) <$> arbitrary
    pure $ UTCTime day seconds

genPhase :: Gen Phase
genPhase =
    oneof
        [ pure RetrievingFunds
        , pure Metadata
        , pure Genesis
        , pure Pool0
        , pure Funding
        , pure Pools
        , pure Relay
        , Cluster <$> oneof [pure Nothing, Just <$> genRunningNode]
        ]

genCardanoNodeConn :: Gen CardanoNodeConn
genCardanoNodeConn = do
    mConn <-
        cardanoNodeConn <$> do
            oneof [pure "path1", pure "path1/path2", pure "/path3"]
    case mConn of
        Left e -> error $ "genCardanoNodeConn: " <> e
        Right conn -> pure conn

genRunningNode :: Gen RunningNode
genRunningNode = do
    socket <- genCardanoNodeConn
    genesis <- genShelleyGenesis
    version <- genNodeToClientVersionData
    pure
        $ RunningNode
            { runningNodeSocketPath = socket
            , runningNodeShelleyGenesis = genesis
            , runningNodeVersionData = version
            }

genNodeToClientVersionData :: Gen NodeToClientVersionData
genNodeToClientVersionData =
    pure
        $ NodeToClientVersionData
            { networkMagic = NetworkMagic 42
            , query = True
            }

genShelleyGenesis :: Gen (ShelleyGenesis StandardCrypto)
genShelleyGenesis = pure $ case fromJSON shelleyGenesis of
    Success genesis -> genesis
    Error e -> error e

shelleyGenesis :: Value
shelleyGenesis =
    [aesonQQ|
{
    "activeSlotsCoeff": 5.0e-2,
    "epochLength": 21600,
    "genDelegs": {
        "8a1cebc0df78b69ef71099de3867a78d85b93b57513fc0508b27bee6": {
            "delegate": "2103d8279e759d7163d1422467cfb88c19e584adc9506d4b8484a397",
            "vrf": "8d8f6e4c0685ca835d7dbe4ec4c240f4d71d0ceb2e4fe1d7bd97b7b3d30f435d"
        }
    },
    "initialFunds": {},
    "maxKESEvolutions": 62,
    "maxLovelaceSupply": 45000000000000000,
    "networkId": "Testnet",
    "networkMagic": 42,
    "protocolParams": {
        "a0": 0.3,
        "decentralisationParam": 1.0,
        "eMax": 18,
        "extraEntropy": {
            "tag": "NeutralNonce"
        },
        "keyDeposit": 2000000,
        "maxBlockBodySize": 65536,
        "maxBlockHeaderSize": 1100,
        "maxTxSize": 16384,
        "minFeeA": 44,
        "minFeeB": 155381,
        "minPoolCost": 340000000,
        "minUTxOValue": 1000000,
        "nOpt": 150,
        "poolDeposit": 500000000,
        "protocolVersion": {
            "major": 6,
            "minor": 0
        },
        "rho": 3.0e-3,
        "tau": 0.2
    },
    "securityParam": 108,
    "slotLength": 1,
    "slotsPerKESPeriod": 129600,
    "staking": {
        "pools": {},
        "stake": {}
    },
    "systemStart": "2024-03-25T10:34:26.544957596Z",
    "updateQuorum": 1
}
|]
