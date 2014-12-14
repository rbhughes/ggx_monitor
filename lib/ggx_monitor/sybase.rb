require "sequel"
require "socket"
require_relative "discovery"

ENV["PATH"] = "#{ENV["PATH"]};c:/dev/sqla64/bin64"

#TODO set this path to lib for depoyment
#sqla64 = File.expand_path('../sqla64/bin64', __FILE__)
#ENV["PATH"] = "#{ENV["PATH"]};#{sqla64}"

class Sybase
  attr_reader :db

  def initialize(proj)
    @db = Sequel.sqlanywhere(:conn_string => Discovery.connect_string(proj))
  end

  at_exit { @db.disconnect if @db }
end

