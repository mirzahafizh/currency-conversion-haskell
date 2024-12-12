{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DeriveGeneric #-}

import Servant
import Network.Wai.Handler.Warp (run)
import Network.HTTP.Simple as HTTP
import GHC.Generics
import Data.Aeson (FromJSON, ToJSON, decode)
import qualified Data.Text as T
import Data.ByteString.Char8 (pack)
import Control.Monad.IO.Class (liftIO) -- Added for IO lifting

-- Data types for parsing ExchangeRate-API response
data ExchangeRateResponse = ExchangeRateResponse
  { result :: String
  , base_code :: String
  , target_code :: String
  , conversion_rate :: Double
  } deriving (Show, Generic)

instance FromJSON ExchangeRateResponse

-- API Type definition
type CurrencyAPI =
       "pair" :> Capture "base" String :> Capture "target" String :> Capture "amount" Double :> Get '[JSON] Double

-- Function to fetch data from ExchangeRate-API with the updated response format
fetchRate :: String -> String -> IO (Maybe Double)
fetchRate baseCurrency targetCurrency = do
  let apiKey = "720c94fc83ffedfbc393183b"  -- Replace with your API key from ExchangeRate-API
  let url = "https://v6.exchangerate-api.com/v6/" ++ apiKey ++ "/pair/" ++ baseCurrency ++ "/" ++ targetCurrency
  putStrLn $ "Fetching URL: " ++ url  -- Debugging: Print the constructed URL
  response <- httpLBS (parseRequest_ url)
  let body = getResponseBody response
  putStrLn $ "Response Body: " ++ show body  -- Debugging: Print the raw response body
  case decode body :: Maybe ExchangeRateResponse of
    Just exchangeRate -> return (Just $ conversion_rate exchangeRate)
    Nothing -> return Nothing
-- Handler for currency conversion
convertHandler :: String -> String -> Double -> Handler Double
convertHandler base target amount = do
  result <- liftIO $ fetchRate base target
  case result of
    Just rate -> return (amount * rate)
    Nothing -> throwError err404 { errBody = "Currency pair not found" }

-- Combine handlers into a server
server :: Server CurrencyAPI
server = convertHandler

-- Proxy for the API
api :: Servant.Proxy CurrencyAPI
api = Servant.Proxy

-- Main function to run the server
main :: IO ()
main = do
  putStrLn "Currency API running on http://localhost:8080"
  run 8080 (serve api server)
