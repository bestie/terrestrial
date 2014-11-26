class QueryCounter
  def initialize
    reset
  end

  def read_count
    @info.count { |query|
      /\A\([0-9\.]+s\) SELECT/i === query
    }
  end

  def info(message)
    @info.push(message)
  end

  def error(message)
    @error.push(message)
  end

  def warn(message)
    @warn.push(message)
  end

  def reset
    @info = []
    @error = []
    @warn = []
  end
end
