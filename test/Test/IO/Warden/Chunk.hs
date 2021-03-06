{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TemplateHaskell   #-}

module Test.IO.Warden.Chunk where

import           Control.Monad.Trans.Resource (runResourceT)

import           Data.ByteString (hPut)
import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BSC
import qualified Data.ByteString.Lazy as LBS
import           Data.Conduit (($$))
import           Data.Conduit.Binary (sinkLbs)
import qualified Data.List.NonEmpty as NE

import           Disorder.Core.IO (testIO)

import           P

import           System.Entropy (getEntropy)
import           System.IO (IO, hClose)

import           Test.IO.Warden
import           Test.QuickCheck
import           Test.QuickCheck.Instances  ()
import           Test.Warden.Arbitrary ()

import           Warden.Chunk
import           Warden.Data

import           X.Data.Conduit.Binary (slurp)

prop_chunk_one :: ChunkCount -> Property
prop_chunk_one n = forAll (arbitrary `suchThat` ((< (1024*1024)) . BS.length)) $ \bs -> 
  testIO . withTestFile $ \fp h -> do
  hPut h bs
  hClose h
  cs <- chunk n fp
  pure $ NE.length cs === 1

prop_chunk_many :: ChunkCount -> Property
prop_chunk_many n = forAll (choose (1024*1024, 10*1024*1024)) $ \m -> -- 1MB-10MB
  testIO . withTestFile $ \fp h -> do
  bs <- getEntropy m
  let nls = BSC.count '\n' bs
  hPut h bs
  hClose h
  cs <- chunk n fp
  pure $ (NE.length cs >= 1, NE.length cs <= nls + 1) === (True, True)

prop_chunk :: ChunkCount -> Property
prop_chunk n = forAll (choose (1, 10*1024*1024)) $ \m -> -- 1B-10MB
  testIO . withTestFile $ \fp h -> do
  bs <- getEntropy m
  hPut h bs
  hClose h
  cs <- chunk n fp
  r1 <- runResourceT $ mapM_ (slurp' fp) cs $$ sinkLbs
  r2 <- LBS.readFile fp
  pure $ r1 === r2
  where
    slurp' fp (Chunk o s) =
      slurp fp (unChunkOffset o) (Just $ unChunkSize s)

return []
tests :: IO Bool
tests = $forAllProperties $ quickCheckWithResult (stdArgs { maxSuccess = 10 })
