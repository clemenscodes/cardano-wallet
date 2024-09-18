module Cardano.Wallet.Deposit.Pure
    (
    -- * Types
      WalletState
    , DeltaWalletState
    , WalletPublicIdentity (..)

    -- * Operations
    -- ** Mapping between customers and addresses
    , Customer
    , listCustomers
    , deriveAddress
    , knownCustomer
    , knownCustomerAddress
    , isCustomerAddress
    , fromRawCustomer
    , customerAddress
    , trackedCustomers
    , walletXPub

    -- ** Reading from the blockchain
    , fromXPubAndGenesis
    , Word31
    , getWalletTip
    , availableBalance
    , rollForwardMany
    , rollForwardOne
    , rollBackward

    , TxSummary (..)
    , ValueTransfer (..)
    , getCustomerHistory
    , getCustomerHistories

    -- ** Writing to the blockchain
    , createPayment
    , BIP32Path (..)
    , DerivationType (..)
    , getBIP32PathsForOwnedInputs
    , signTxBody

    , addTxSubmission
    , listTxsInSubmission
    ) where

import Prelude

import Cardano.Crypto.Wallet
    ( XPrv
    , XPub
    )
import Cardano.Wallet.Address.BIP32
    ( BIP32Path (..)
    , DerivationType (..)
    )
import Cardano.Wallet.Deposit.Pure.UTxOHistory
    ( UTxOHistory
    )
import Cardano.Wallet.Deposit.Read
    ( Address
    )
import Data.Foldable
    ( foldl'
    )
import Data.List.NonEmpty
    ( NonEmpty
    )
import Data.Map.Strict
    ( Map
    )
import Data.Maybe
    ( mapMaybe
    )
import Data.Set
    ( Set
    )
import Data.Word.Odd
    ( Word31
    )

import qualified Cardano.Wallet.Deposit.Pure.Address as Address
import qualified Cardano.Wallet.Deposit.Pure.Balance as Balance
import qualified Cardano.Wallet.Deposit.Pure.Submissions as Sbm
import qualified Cardano.Wallet.Deposit.Pure.UTxO as UTxO
import qualified Cardano.Wallet.Deposit.Pure.UTxOHistory as UTxOHistory
import qualified Cardano.Wallet.Deposit.Read as Read
import qualified Cardano.Wallet.Deposit.Write as Write
import qualified Data.Delta as Delta
import qualified Data.Set as Set

{-----------------------------------------------------------------------------
    Types
------------------------------------------------------------------------------}
type Customer = Address.Customer

data WalletState = WalletState
    { addresses :: !Address.AddressState
    , utxoHistory :: !UTxOHistory.UTxOHistory
    -- , txHistory :: [Read.Tx]
    , submissions :: Sbm.TxSubmissions
    , rootXSignKey :: Maybe XPrv
    -- , info :: !WalletInfo
    }

type DeltaWalletState = Delta.Replace WalletState

data WalletPublicIdentity = WalletPublicIdentity
    { pubXpub :: XPub
    , pubNextUser :: Word31
    }
    deriving Show

{-----------------------------------------------------------------------------
    Operations
    Mapping between customers and addresses
------------------------------------------------------------------------------}

listCustomers :: WalletState -> [(Customer, Address)]
listCustomers =
    Address.listCustomers . addresses

customerAddress :: Customer -> WalletState -> Maybe Address
customerAddress c = lookup c . listCustomers

-- depend on the private key only, not on the entire wallet state
deriveAddress :: WalletState -> (Customer -> Address)
deriveAddress w =
    Address.deriveAddress (Address.getXPub (addresses w))
    . Address.DerivationCustomer

-- FIXME: More performant with a double index.
knownCustomer :: Customer -> WalletState -> Bool
knownCustomer c = (c `elem`) . map fst . listCustomers

knownCustomerAddress :: Address -> WalletState -> Bool
knownCustomerAddress address =
    Address.knownCustomerAddress address . addresses

isCustomerAddress :: Address -> WalletState -> Bool
isCustomerAddress address =
    flip Address.isCustomerAddress address . addresses

fromRawCustomer :: Word31 -> Customer
fromRawCustomer = id

trackedCustomers :: WalletState -> Customer
trackedCustomers = fromIntegral . length . Address.addresses . addresses

walletXPub :: WalletState -> XPub
walletXPub  = Address.getXPub . addresses

{-----------------------------------------------------------------------------
    Operations
    Reading from the blockchain
------------------------------------------------------------------------------}

fromXPubAndGenesis :: XPub -> Word31 -> Read.GenesisData -> WalletState
fromXPubAndGenesis xpub knownCustomerCount _ =
    WalletState
        { addresses =
            Address.fromXPubAndCount xpub knownCustomerCount
        , utxoHistory = UTxOHistory.empty initialUTxO
        , submissions = Sbm.empty
        , rootXSignKey = Nothing
        }
  where
    initialUTxO = mempty

getWalletTip :: WalletState -> Read.ChainPoint
getWalletTip = error "getWalletTip"

rollForwardMany :: NonEmpty Read.Block -> WalletState -> WalletState
rollForwardMany blocks w = foldl' (flip rollForwardOne) w blocks

rollForwardOne :: Read.Block -> WalletState -> WalletState
rollForwardOne block w =
    w
        { utxoHistory = rollForwardUTxO isOurs block (utxoHistory w)
        , submissions = Delta.apply (Sbm.rollForward block) (submissions w)
        }
  where
    isOurs :: Address -> Bool
    isOurs = Address.isOurs (addresses w)

rollForwardUTxO
    :: (Address -> Bool) -> Read.Block -> UTxOHistory -> UTxOHistory
rollForwardUTxO isOurs block u =
    UTxOHistory.appendBlock slot deltaUTxO u
  where
    (deltaUTxO,_) = Balance.applyBlock isOurs block (UTxOHistory.getUTxO u)
    slot = Read.slotNo . Read.blockHeaderBody $ Read.blockHeader block

rollBackward
    :: Read.ChainPoint
    -> WalletState
    -> (WalletState, Read.ChainPoint)
rollBackward point w = (w, point) -- FIXME: This is a mock implementation

availableBalance :: WalletState -> Read.Value
availableBalance = UTxO.balance . availableUTxO

availableUTxO :: WalletState -> UTxO.UTxO
availableUTxO w =
    Balance.availableUTxO utxo pending
  where
    pending = listTxsInSubmission w
    utxo = UTxOHistory.getUTxO $ utxoHistory w

data TxSummary = TxSummary
    { txid :: Read.TxId
    , blockHeaderBody :: Read.BHBody
    , transfer :: ValueTransfer
    }
    deriving (Eq, Show)

data ValueTransfer = ValueTransfer
    { spent :: Read.Value
    , received :: Read.Value
    }
    deriving (Eq, Show)

getCustomerHistory :: Customer -> WalletState -> [TxSummary]
getCustomerHistory = undefined

-- TODO: Return an error if any of the `ChainPoint` are no longer
-- part of the consensus chain?
getCustomerHistories
    :: (Read.ChainPoint, Read.ChainPoint)
    -> WalletState
    -> Map Customer ValueTransfer
getCustomerHistories = undefined

{-----------------------------------------------------------------------------
    Operations
    Writing to blockchain
------------------------------------------------------------------------------}

createPayment :: [(Address, Write.Value)] -> WalletState -> Maybe Write.TxBody
createPayment = undefined
    -- needs balanceTx
    -- needs to sign the transaction

getBIP32PathsForOwnedInputs :: Write.TxBody -> WalletState -> [BIP32Path]
getBIP32PathsForOwnedInputs txbody w =
    getBIP32Paths w
    . resolveInputAddresses
    $ Write.spendInputs txbody <> Write.collInputs txbody
  where
    resolveInputAddresses :: Set Read.TxIn -> [Read.Address]
    resolveInputAddresses ins =
        map (Read.address . snd)
        . UTxO.toList
        $ UTxO.restrictedBy (availableUTxO w) ins

getBIP32Paths :: WalletState -> [Read.Address] -> [BIP32Path]
getBIP32Paths w =
    mapMaybe $ Address.getBIP32Path (addresses w)

signTxBody :: Write.TxBody -> WalletState -> Maybe Write.Tx
signTxBody _txbody _w = undefined

addTxSubmission :: Write.Tx -> WalletState -> WalletState
addTxSubmission _tx _w = undefined

listTxsInSubmission :: WalletState -> Set Write.Tx
-- listTxsInSubmission = Sbm.listInSubmission . submissions
listTxsInSubmission _ = Set.empty
