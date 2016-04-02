require "logger"
require "sequel_mapper/public_conveniencies"

module Terrestrial
  extend PublicConveniencies

  LOGGER = Logger.new(STDERR)
end
