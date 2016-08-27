-- | Functions tightly related to HBlock

module RSCoin.Core.HBlock
       ( initialTx
       , mkHBlock
       , mkGenesisHBlock
       , checkHBlock
       ) where

import qualified Data.Map               as M

import           RSCoin.Core.Constants  (genesisValue)
import           RSCoin.Core.Crypto     (PublicKey, SecretKey, hash, sign,
                                         unsafeHash, verify)
import           RSCoin.Core.Primitives (Address, Transaction (..))
import           RSCoin.Core.Strategy   (AddressToTxStrategyMap)
import           RSCoin.Core.Types      (Dpk, HBlock (..), HBlockHash (..))

initialHash :: HBlockHash
initialHash = HBlockHash $ unsafeHash ()

initialTx :: Address -> Transaction
initialTx genAdr =
    Transaction
    { txInputs = []
    , txOutputs = [(genAdr, genesisValue)]
    }

-- | Construct higher-level block from txset, Bank's secret key, DPK
-- and previous block.
mkHBlock :: [Transaction] -> HBlock -> AddressToTxStrategyMap -> SecretKey -> Dpk -> HBlock
mkHBlock txset prevBlock newAddrs sk dpk = mkHBlockDo txset newAddrs sk dpk (hbHash prevBlock)

-- | Construct genesis higher-level block using Bank's secret key and DPK.
mkGenesisHBlock :: Address -> SecretKey -> Dpk -> HBlock
mkGenesisHBlock genAdr sk dpk = mkHBlockDo [initialTx genAdr] M.empty sk dpk initialHash

mkHBlockDo :: [Transaction]
           -> AddressToTxStrategyMap
           -> SecretKey
           -> Dpk
           -> HBlockHash
           -> HBlock
mkHBlockDo hbTransactions hbAddresses sk hbDpk prevHash = HBlock {..}
  where
    hbHash :: HBlockHash
    hbHash = HBlockHash $ hash (prevHash, hbTransactions)
    hbSignature = sign sk hbHash

-- | Check that higher-level block is valid using Bank's public key
-- and previous block (unless it's genesis block).
checkHBlock :: PublicKey -> Maybe HBlock -> HBlock -> Bool
checkHBlock pk Nothing blk  = checkHBlockDo pk initialHash blk
checkHBlock pk (Just b) blk = checkHBlockDo pk (hbHash b) blk

checkHBlockDo :: PublicKey -> HBlockHash -> HBlock -> Bool
checkHBlockDo pk prevHash HBlock{..} =
    and (checkHash : checkSignature : map checkDpk hbDpk)
  where
    checkHash = getHBlockHash hbHash == hash (prevHash, hbTransactions)
    checkSignature = verify pk hbSignature hbHash
    checkDpk (mPk,signature) = verify pk signature mPk
