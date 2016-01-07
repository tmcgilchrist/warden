{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE LambdaCase #-}

import           Data.Char (ord)
import qualified Data.List.NonEmpty as NE
import qualified Data.Text.IO as T

import           Options.Applicative

import           P

import           System.Exit (exitSuccess, exitFailure)
import           System.IO (IO, print)

import           Warden.Commands
import           Warden.Data
import           Warden.Error

import           X.Control.Monad.Trans.Either.Exit (orDie)
import           X.Options.Applicative

data Command = Check CheckParams
  deriving (Eq, Show)

main :: IO ()
main = do
  dispatch (safeCommand wardenP) >>= \case
    VersionCommand -> do
      exitSuccess
    RunCommand DryRun c -> do
      print c
      exitSuccess
    RunCommand RealRun (Check ps) -> do
      r <- orDie renderWardenError $ check ps
      mapM_ T.putStrLn . NE.toList . (=<<) renderCheckResult $ r
      if checkHasFailures r
        then exitFailure
        else exitSuccess

wardenP :: Parser Command
wardenP = subparser $
     command' "check" "Run checks over a view." checkP

checkP :: Parser Command
checkP = Check <$> (CheckParams <$> viewP <*> separatorP)

viewP :: Parser View
viewP = View <$> (strArgument $
     metavar "VIEW"
  <> help "Path to local copy of view.")

separatorP :: Parser Separator
separatorP = option (eitherReader separator) $
     long "separator"
  <> short 's'
  <> metavar "SEPARATOR"
  <> value (Separator . fromIntegral $ ord '|')
  <> help "Field separator for view (e.g., pipe or comma). Defaults to '|'."
  where
    separator x = maybe (Left $ "Invalid separator " <> x) Right $ valid' x
    valid' [x] = if ord x >= 32 && ord x < 128
      then Just . Separator . fromIntegral $ ord x
      else Nothing
    valid' _   = Nothing
      
