require "logger"
require "terrestrial/public_conveniencies"

module Terrestrial
  extend PublicConveniencies

  LOGGER = Logger.new(STDERR)
end
