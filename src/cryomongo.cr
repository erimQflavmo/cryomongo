require "log"
require "bson"
require "./mongo/messages/**"
require "./mongo/client"

module Mongo
  VERSION = "0.1.0"

  Log = ::Log.for(self)
end