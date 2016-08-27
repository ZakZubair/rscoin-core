{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TupleSections       #-}

-- | Functions related to Transaction

module RSCoin.Core.Transaction
       ( validateSum
       , validateSignature
       , getAmountByAddress
       , getAddrIdByAddress
       , chooseAddresses
       , computeOutputAddrids
       ) where

import           Control.Arrow          ((&&&))
import           Control.Exception      (assert)
import           Control.Lens           (view, _3)
import           Data.Foldable          (foldl', foldr')
import           Data.Function          (on)
import qualified Data.IntMap.Strict     as M
import           Data.List              (delete, groupBy, nub, sortBy)
import           Data.Ord               (comparing)

import           RSCoin.Core.Coin       (coinsToMap)
import           RSCoin.Core.Crypto     (Signature, hash, verify)
import           RSCoin.Core.Primitives (AddrId, Address (..), Coin (..),
                                         Color (..), Transaction (..), grey)

-- | Validates that sum of inputs for each color isn't greater than
-- sum of outputs, and what's left can be painted by grey coins.
validateSum :: Transaction -> Bool
validateSum Transaction{..} =
    and [ totalInputs >= totalOutputs
        , greyInputs >= greyOutputs + totalUnpaintedSum ]
  where
    inputs  = coinsToMap $ map (view _3) txInputs
    outputs = coinsToMap $ map snd txOutputs
    totalInputs  = sum $ map getCoin $ M.elems inputs
    totalOutputs = sum $ map getCoin $ M.elems outputs
    greyInputs  = getCoin $ M.findWithDefault 0 (getC grey) inputs
    greyOutputs = getCoin $ M.findWithDefault 0 (getC grey) outputs
    txColors = delete (getC grey) $ nub $ (M.keys inputs ++ M.keys outputs)
    foldfoo0 color unp =
        let zero = Coin (Color color) 0
            outputOfThisColor = M.findWithDefault zero color outputs
            inputOfThisColor = M.findWithDefault zero color inputs
        in if outputOfThisColor <= inputOfThisColor
           then unp
           else M.insert color (outputOfThisColor - inputOfThisColor) unp
    unpainted = foldr' foldfoo0 M.empty txColors
    totalUnpaintedSum = sum $ map getCoin $ M.elems unpainted

-- | Validates that signature is issued by public key associated with given
-- address for the transaction.
validateSignature :: Signature Transaction -> Address -> Transaction -> Bool
validateSignature signature (Address pk) = verify pk signature

-- | Given address and transaction returns total amount of money
-- transaction transfers to address.
getAmountByAddress :: Address -> Transaction -> M.IntMap Coin
getAmountByAddress addr Transaction{..} =
    let pair c = (getC $ getColor c, c) in
    M.fromListWith (+) $ map (pair . snd) $ filter ((==) addr . fst) txOutputs

-- | Given address a and transaction returns all addrids that have
-- address equal to a.
getAddrIdByAddress :: Address -> Transaction -> [AddrId]
getAddrIdByAddress addr transaction@Transaction{..} =
    let h = hash transaction in
    map (\(i,(_,c)) -> (h,i,c)) $
        filter ((==) addr . fst . snd) $ [(0 :: Int)..] `zip` txOutputs

-- | For each color, computes optimal usage of addrids to pay the given amount of
-- coins. Sum of coins of those addrids should be greater
-- or equal to given value, for each color. Here 'optimal' stands for 'trying to
-- include as many addrids as possible', so that means function takes
-- addrids with smaller amount of money first.
chooseAddresses :: [AddrId] -> M.IntMap Coin -> Maybe (M.IntMap ([AddrId], Coin))
chooseAddresses addrids valueMap =
    chooseOptimal addrids' (view _3) valueMap'
    where addrids' = filter ((/=0) . getCoin . view _3) addrids
          valueMap' = M.filter ((/=0) . getCoin) valueMap

chooseOptimal
    :: forall a.
       [a]                             -- ^ Elements we're choosing from
    -> (a -> Coin)                     -- ^ Getter of coins from the element
    -> M.IntMap Coin                -- ^ Map with amount of coins for each color
    -> Maybe (M.IntMap ([a], Coin)) -- ^ Map with chosen elements and change for each color
                                       -- If nothing, value can't be chosen (no money)
chooseOptimal addrids coinGetter valueMap =
    -- In case there are less colors in addrList than in valueList
    -- filler coins are added to short-circuit the comparison of lists.
    assert
        (map (sum . map coinGetter) addrList ++ repeat (Coin 0 0) >= M.elems valueMap) $
    M.fromList <$> mapM
        (\(color, value) ->
              (color,) <$> chooseHelper (M.findWithDefault [] color addrMap) value)
        (M.toList valueMap)
  where
    -- List of lists of addrids. Each sublist has the same color
    -- and the extern list is sorted by it. Inner list of the same
    -- color is sorted by coins amount.
    addrList :: [[a]]
    addrList =
        groupBy ((==) `on` (getColor . coinGetter)) $
        sortBy (comparing (getColor . coinGetter)) $
        sortBy (comparing (getCoin . coinGetter)) addrids
    -- addrMap :: M.Map Color [a]
    -- Map from each color to addrids with a coin of that color
    addrMap = M.fromList $ map ((getC . getColor . coinGetter . head) &&& id) addrList
    -- chooseHelper :: [a] -> Coin -> ([a], Coin)
    -- This function goes through a list of addrids and calculates the optimal
    chooseHelper list value =
        -- choice of addrids and the coins that are left
        let foldFoo o@(_,_,Just _) _ = o
            foldFoo (accum,values,Nothing) e =
                let val = coinGetter e
                    newAccum = accum + val
                    newValues = e : values
                in ( newAccum
                   , newValues
                   , if newAccum >= value
                     then Just $ newAccum - value
                     else Nothing)
        in case foldl' foldFoo (Coin (getColor value) 0, [], Nothing) list of
                    (_,chosenAIds,Just whatsLeft) -> Just (chosenAIds, whatsLeft)
                    (_,_,Nothing) -> Nothing

-- | This function creates for every address ∈ S_{out} a pair
-- (addr,addrid), where addrid is exactly a usage of this address in
-- this transasction
computeOutputAddrids :: Transaction -> [(AddrId, Address)]
computeOutputAddrids tx@Transaction{..} =
    let h = hash tx in
    map (\((addr, coin), i) -> ((h, i, coin), addr)) $ txOutputs `zip` [0..]
