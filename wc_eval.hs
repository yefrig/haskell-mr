{-# LANGUAGE TupleSections #-}

import Control.Parallel(pseq)
import Control.Parallel.Strategies
import Data.Char(isAlpha, toLower)
import Data.Map(Map, fromListWith, toList, unionsWith)
import qualified Data.ByteString.Lazy.Char8 as B
import Data.List(sortBy)
import Data.Function(on)
import System.Environment(getArgs, getProgName)
import System.Exit(die)

{-

 Name: Ecenaz Ozmen and Yefri Gaitan
 Uni: eo2419 and yg2548

 ------------------------------

 COMS 4995 003 Parallel Functional Programming

 Final Project: MapReduce Word Counter 

 to compile:
 stack ghc -- -O2 -Wall -threaded -rtsopts -eventlog wc_eval

to run sequantial word count:
 ./wc_eval big.txt seq +RTS -N4 -ls -s
to run parallel word count:
 ./wc_eval big.txt par +RTS -N4 -ls -s

-}

main :: IO()
main = do 
    args <- getArgs
    case args of 
        [filename, "par"] -> do
            content <- B.readFile filename
            print $ take 10 $ sort $ wcpar content
        [filename, "seq"] -> do
            content <- B.readFile filename
            print $ take 10 $ sort $ wcseq content
        _ -> do 
            pn <- getProgName
            die $ "Usage: " ++ pn ++ " <filename> <par/seq>"
        
wcseq :: B.ByteString -> [(B.ByteString, Int)]
wcseq = seqMapReduce wcmap wcreduce . split 100000

wcpar :: B.ByteString -> [(B.ByteString, Int)]
wcpar = finalreduce . parMapReduce rdeepseq wcmap rseq parwcreduce . split 100000

-- word count helper functions

wcmap :: [B.ByteString] -> [(B.ByteString, Int)]
wcmap = map (, 1) 

parwcreduce :: [(B.ByteString, Int)] -> Map B.ByteString Int
parwcreduce = fromListWith (+)

finalreduce :: [Map B.ByteString Int] -> [(B.ByteString, Int)]
finalreduce = toList . unionsWith (+)

wcreduce :: [[(B.ByteString, Int)]] -> [(B.ByteString, Int)]
wcreduce  = toList . fromListWith (+) . concat 


-- map reduce library

seqMapReduce :: (a   -> b) -> ([b] -> c) -> [a] -> c
seqMapReduce mf rf = rf . map mf

parMapReduce
    :: Strategy b  -- for mapping
    -> (a   -> b)  -- map func
    -> Strategy c  -- for reducing
    -> (b -> c)  -- reduce func
    -> [a]         -- init list
    -> [c]
parMapReduce mstrat mf rstrat rf xs =
    mres `pseq` rres
  where mres = map mf xs `using` parBuffer 200 mstrat
        rres = map rf mres `using` parBuffer 200 rstrat  -- [[(B.ByteString, Int)]] 


-- Helper functions

sort :: Ord b => [(a,b)] -> [(a,b)]
sort = sortBy (flip compare `on` snd)

split :: Int -> B.ByteString -> [[B.ByteString]]
split n bs = chunk n $ map removeNonLetters $ B.words bs

chunk :: Int -> [a] -> [[a]]
chunk _ [] = []
chunk n xs = let (as,bs) = splitAt n xs in as : chunk n bs

removeNonLetters :: B.ByteString -> B.ByteString
removeNonLetters = B.filter isAlpha . B.map toLower
