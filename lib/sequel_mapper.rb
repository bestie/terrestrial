require "logger"
require "sequel_mapper/public_conveniencies"

module SequelMapper
  extend PublicConveniencies

  LOGGER = Logger.new(STDERR)
end
