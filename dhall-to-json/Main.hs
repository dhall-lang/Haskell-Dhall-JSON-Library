{-# LANGUAGE DataKinds         #-}
{-# LANGUAGE DeriveGeneric     #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
{-# LANGUAGE TypeOperators     #-}

module Main where

import Control.Exception (SomeException)
import Options.Generic (Generic, ParseRecord, Wrapped, type (<?>), type (:::))

import qualified Control.Exception
import qualified Data.Aeson
import qualified Data.Aeson.Encode.Pretty
import qualified Data.ByteString.Char8
import qualified Data.ByteString.Lazy
import qualified Data.Text.IO
import qualified Dhall
import qualified Dhall.JSON
import qualified GHC.IO.Encoding
import qualified Options.Generic
import qualified System.Exit
import qualified System.IO

data Options w = Options
    { explain  :: w ::: Bool <?> "Explain error messages in detail"
    , pretty   :: w ::: Bool <?> "Pretty print generated JSON"
    , omitNull :: w ::: Bool <?> "Omit record fields that are null"
    } deriving (Generic)

instance ParseRecord (Options Wrapped)

main :: IO ()
main = do
    GHC.IO.Encoding.setLocaleEncoding GHC.IO.Encoding.utf8

    Options {..} <- Options.Generic.unwrapRecord "Compile Dhall to JSON"

    handle $ do
        let encode =
                if pretty
                then Data.Aeson.Encode.Pretty.encodePretty
                else Data.Aeson.encode

        let explaining = if explain then Dhall.detailed else id

        let omittingNull = if omitNull then Dhall.JSON.omitNull else id

        stdin <- Data.Text.IO.getContents

        json <- omittingNull <$> explaining (Dhall.JSON.codeToValue "(stdin)" stdin)

        Data.ByteString.Char8.putStrLn $ Data.ByteString.Lazy.toStrict $ encode json

handle :: IO a -> IO a
handle = Control.Exception.handle handler
  where
    handler :: SomeException -> IO a
    handler e = do
        System.IO.hPutStrLn System.IO.stderr ""
        System.IO.hPrint    System.IO.stderr e
        System.Exit.exitFailure
