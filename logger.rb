# coding: utf-8

require 'pp'

class DCLogger

  def initialize
    @log = Syslog::Logger.new 'destcloud2'
  end

  def log(uuid ="<uuid none>",type="<type none>", message="<no message>")
    @log.info ("#{uuid} #{type} #{message}")
  end

  def debug(message = "<no message>")
      pp message
  end
end

