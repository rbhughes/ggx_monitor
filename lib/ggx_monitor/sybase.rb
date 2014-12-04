require "sequel"
require "socket"

ENV["PATH"] = "#{ENV["PATH"]};c:/dev/sqla64/bin64"

#TODO set this path to lib for depoyment
#sqla64 = File.expand_path('../sqla64/bin64', __FILE__)
#ENV["PATH"] = "#{ENV["PATH"]};#{sqla64}"

class Sybase

  attr_reader :db, :project_server, :project_home, :project_name

  def initialize(proj)
    @db = Sequel.sqlanywhere(:conn_string => connect_string(proj))
    @project_server
    @project_home
    @project_name
  end

  at_exit { @db.disconnect if @db }

  private

  # Make the DBN string combo based on project home and project name
  # <project>-<home>  (with spaces replaced with underscores
  def get_ggx_dbn(proj)
    ini = File.join(File.dirname(proj), "home.ini")
    m = File.read(ini).match /Name=(.*)/
    @project_home = m[1]
    @project_name = File.basename(proj)
    "#{@project_name}-#{@project_home}".gsub(" ", "_")
  end

  # Pluck the hostname from either the UNC path or local host
  # Backslashes have already been replaced with forward slashes.
  def get_host(proj)
    @project_server = (proj.match /^\/\//) ? 
      (proj.match /^\/\/(\w+)/)[1] : Socket.gethostname
    #@project_server = (proj.match /^\\\\/) ? 
    #  (proj.match /^\\\\(\w+)/)[1] : Socket.gethostname
  end

  # Build a connect string that Sybase will use. This style mimics what
  # GeoGraphix does and should allow concurrent access:
  #
  # UID=dba;PWD=sql;DBF='\\OKC1GGX0006\e$\Oklahoma\NW Oklahoma/gxdb.db';
  # DBN=NW_Oklahoma-Oklahoma;HOST=OKC1GGX0006;Server=GGX_OKC1GGX0006
  #
  def connect_string(proj)
    host = get_host(proj)
    conn = []
    conn << "UID=dba"
    conn << "PWD=sql"
    conn << "DBF='#{File.join(proj,'gxdb.db')}'"
    conn << "DBN=#{get_ggx_dbn(proj)}"
    conn << "HOST=#{host}"
    conn << "Server=GGX_#{host}"
    conn.join(";")
  end

end

