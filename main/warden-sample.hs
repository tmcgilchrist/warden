{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE OverloadedStrings #-}

import           BuildInfo_ambiata_warden
import           DependencyInfo_ambiata_warden

import           Control.Monad.Trans.Resource (runResourceT)

import           Options.Applicative (Parser)
import           Options.Applicative (subparser)
import           Options.Applicative (long, short, help)
import           Options.Applicative (metavar, strArgument, strOption)

import           P

import           System.IO (IO, BufferMode(..), FilePath)
import           System.IO (stdout, stderr, hSetBuffering)

import           Warden.Commands.Sample
import           Warden.Error

import           X.Control.Monad.Trans.Either (mapEitherT)
import           X.Control.Monad.Trans.Either.Exit (orDie)
import           X.Options.Applicative (cli, command')

data Command =
    Extract !FilePath ![FilePath]
  deriving (Eq, Show)

main :: IO ()
main = do
  hSetBuffering stdout LineBuffering
  hSetBuffering stderr LineBuffering
  cli "warden-sample" buildInfoVersion dependencyInfo commandP $ \cmd ->
    case cmd of
      Extract op fs -> do
        orDie renderWardenError . mapEitherT runResourceT $
          extractNumericFields op fs

commandP :: Parser Command
commandP = subparser $
     command'
       "extract"
       "Extract the numeric samples from a set of marker files into a CSV format more suited to interactive data analysis."
       (Extract <$> csvOutputFileP <*> some markerFileP)

csvOutputFileP :: Parser FilePath
csvOutputFileP = strOption $
     metavar "CSV-OUTPUT-FILE"
  <> long "csv-output-file"
  <> short 'o'
  <> help "Path to write CSV output."

-- FIXME: dedupe (also in main warden cli)
markerFileP :: Parser FilePath
markerFileP = strArgument $
     metavar "MARKER-FILE"
  <> help "Path to view marker file(s) from `warden check`."
