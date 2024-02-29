{-# LANGUAGE DataKinds #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE NamedFieldPuns #-}
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Cardano.Wallet.Delegation
    ( joinStakePoolDelegationAction
    , guardJoin
    , guardQuit
    , quitStakePoolDelegationAction
    , DelegationRequest(..)
    , voteAction
    ) where

import Prelude

import qualified Cardano.Wallet.Primitive.Types as W
import qualified Cardano.Wallet.Transaction as Tx
import qualified Data.Set as Set

import Cardano.Pool.Types
    ( PoolId (..)
    )
import Cardano.Wallet
    ( ErrCannotQuit (..)
    , ErrStakePoolDelegation (..)
    , PoolRetirementEpochInfo (..)
    , WalletException (..)
    , WalletLog (..)
    , fetchRewardBalance
    , isStakeKeyRegistered
    , readDelegation
    )
import Cardano.Wallet.DB
    ( DBLayer (..)
    )
import Cardano.Wallet.DB.Store.Delegations.Layer
    ( CurrentEpochSlotting
    )
import Cardano.Wallet.Primitive.Types
    ( IsDelegatingTo (..)
    , PoolLifeCycleStatus
    , WalletDelegation (..)
    )
import Cardano.Wallet.Primitive.Types.Coin
    ( Coin (..)
    )
import Cardano.Wallet.Primitive.Types.DRep
    ( DRep
    )
import Cardano.Wallet.Transaction
    ( ErrCannotJoin (..)
    , Withdrawal (..)
    )
import Control.Error
    ( lastMay
    )
import Control.Exception
    ( throwIO
    )
import Control.Monad
    ( forM_
    , unless
    , when
    , (>=>)
    )
import Control.Monad.Except
    ( ExceptT
    , runExceptT
    )
import Control.Monad.IO.Class
    ( MonadIO (..)
    )
import Control.Monad.Trans.Except
    ( except
    )
import Control.Tracer
    ( Tracer
    , traceWith
    )
import Data.Generics.Internal.VL.Lens
    ( view
    , (^.)
    )
import Data.Set
    ( Set
    )

-- | The data type that represents client's delegation request.
-- Stake key registration is made implicit by design:
-- the library figures out if stake key needs to be registered first
-- so that clients don't have to worry about this concern.
data DelegationRequest
    = Join PoolId
    -- ^ Delegate to a pool using the default staking key (derivation index 0),
    -- registering the stake key if needed.
    | Quit
    -- ^ Stop delegating if the wallet is delegating.
    deriving (Eq, Show)

voteAction
    :: Tracer IO WalletLog
    -> DBLayer IO s
    -> DRep
    -> IO Tx.VotingAction
voteAction tr DBLayer{..} action = do
    (_, stakeKeyIsRegistered) <-
        atomically $
            (,) <$> readDelegation walletState
                <*> isStakeKeyRegistered walletState

    traceWith tr $ MsgIsStakeKeyRegistered stakeKeyIsRegistered

    pure $
        if stakeKeyIsRegistered
        then Tx.Vote action
        else Tx.VoteRegisteringKey action

joinStakePoolDelegationAction
    :: Tracer IO WalletLog
    -> DBLayer IO s
    -> CurrentEpochSlotting
    -> Set PoolId
    -> PoolId
    -> PoolLifeCycleStatus
    -> IO Tx.DelegationAction
joinStakePoolDelegationAction
    tr DBLayer{..} currentEpochSlotting
        knownPools poolId poolStatus = do
    (walletDelegation, stakeKeyIsRegistered) <-
        atomically $
            (,) <$> readDelegation walletState
                <*> isStakeKeyRegistered walletState

    let retirementInfo =
            PoolRetirementEpochInfo (currentEpochSlotting ^. #currentEpoch)
                . view #retirementEpoch <$>
                W.getPoolRetirementCertificate poolStatus

    throwInIO ErrStakePoolJoin . except
        $ guardJoin
            knownPools
            (walletDelegation currentEpochSlotting)
            poolId
            retirementInfo

    traceWith tr $ MsgIsStakeKeyRegistered stakeKeyIsRegistered

    pure $
        if stakeKeyIsRegistered
        then Tx.Join poolId
        else Tx.JoinRegisteringKey poolId

  where
    throwInIO ::
        MonadIO m => (e -> ErrStakePoolDelegation) -> ExceptT e m a -> m a
    throwInIO f = runExceptT >=>
        either (liftIO . throwIO . ExceptionStakePoolDelegation . f) pure

guardJoin
    :: Set PoolId
    -> WalletDelegation
    -> PoolId
    -> Maybe PoolRetirementEpochInfo
    -> Either ErrCannotJoin ()
guardJoin knownPools delegation pid mRetirementEpochInfo = do
    when (pid `Set.notMember` knownPools) $
        Left (ErrNoSuchPool pid)

    forM_ mRetirementEpochInfo $ \info ->
        when (currentEpoch info >= retirementEpoch info) $
            Left (ErrNoSuchPool pid)

    when ((null next) && isDelegatingTo (== pid) active) $
        Left (ErrAlreadyDelegating pid)

    when (not (null next) && isDelegatingTo (== pid) (last next)) $
        Left (ErrAlreadyDelegating pid)
  where
    WalletDelegation {active, next} = delegation

-- | Helper function to factor necessary logic for quitting a stake pool.
quitStakePoolDelegationAction
    :: forall s
     . DBLayer IO s
    -> CurrentEpochSlotting
    -> Withdrawal
    -> IO Tx.DelegationAction
quitStakePoolDelegationAction db@DBLayer{..} currentEpochSlotting withdrawal = do
    delegation <- atomically $ readDelegation walletState
    rewards <- liftIO $ fetchRewardBalance db
    either (throwIO . ExceptionStakePoolDelegation . ErrStakePoolQuit) pure
        (guardQuit (delegation currentEpochSlotting) withdrawal rewards)
    pure Tx.Quit

guardQuit :: WalletDelegation -> Withdrawal -> Coin -> Either ErrCannotQuit ()
guardQuit WalletDelegation{active,next} wdrl rewards = do
    let last_ = maybe active (view #status) $ lastMay next
    let anyone _ = True
    unless (isDelegatingTo anyone last_) $ Left ErrNotDelegatingOrAboutTo
    case wdrl of
        WithdrawalSelf {} -> Right ()
        _
            | rewards == Coin 0  -> Right ()
            | otherwise          -> Left $ ErrNonNullRewards rewards
