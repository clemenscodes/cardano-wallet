{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Wallet.Deposit.Pure
    ( -- * Types
      WalletState
    , DeltaWalletState
    , WalletPublicIdentity (..)

      -- * Operations

      -- ** Mapping between customers and addresses
    , Customer
    , listCustomers
    , addressToCustomer
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
    , availableUTxO
    , rollForwardMany
    , rollForwardOne
    , rollBackward
    , ValueTransfer (..)
    , getTxHistoryByCustomer
    , getTxHistoryByTime
    , getEraSlotOfBlock
    , getCustomerDeposits
    , getAllDeposits

      -- ** Writing to the blockchain
    , ErrCreatePayment (..)
    , createPayment
    , BIP32Path (..)
    , DerivationType (..)
    , getBIP32PathsForOwnedInputs
    , signTx
    , addTxSubmission
    , listTxsInSubmission
    ) where

import Cardano.Wallet.Address.BIP32
    ( BIP32Path (..)
    , DerivationType (..)
    )
import Cardano.Wallet.Deposit.Pure.State.Creation
    ( WalletPublicIdentity (..)
    , fromXPubAndGenesis
    )
import Cardano.Wallet.Deposit.Pure.State.Payment
    ( ErrCreatePayment (..)
    , createPayment
    )
import Cardano.Wallet.Deposit.Pure.State.Rolling
    ( rollBackward
    , rollForwardMany
    , rollForwardOne
    )
import Cardano.Wallet.Deposit.Pure.State.Signing
    ( getBIP32PathsForOwnedInputs
    , signTx
    )
import Cardano.Wallet.Deposit.Pure.State.Submissions
    ( addTxSubmission
    , availableBalance
    , availableUTxO
    , listTxsInSubmission
    )
import Cardano.Wallet.Deposit.Pure.State.TxHistory
    ( getAllDeposits
    , getCustomerDeposits
    , getTxHistoryByCustomer
    , getTxHistoryByTime
    )
import Cardano.Wallet.Deposit.Pure.State.Type
    ( Customer
    , DeltaWalletState
    , WalletState
    , addressToCustomer
    , customerAddress
    , deriveAddress
    , fromRawCustomer
    , getWalletTip
    , isCustomerAddress
    , knownCustomer
    , knownCustomerAddress
    , listCustomers
    , trackedCustomers
    , walletXPub
    )
import Cardano.Wallet.Deposit.Pure.UTxO.ValueTransfer
    ( ValueTransfer (..)
    )
import Cardano.Wallet.Deposit.Read
    ( getEraSlotOfBlock
    )
import Data.Word.Odd
    ( Word31
    )
