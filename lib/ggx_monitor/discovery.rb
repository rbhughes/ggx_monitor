module Discovery

  #----------
  def self.project_list(root, deep_scan)
    root = root.gsub("\\","/")
    projects = []
    recurse = deep_scan ? "**" : "*"
    Dir.glob(File.join(root, recurse, "*.ggx")).each do |ggx|
      proj = File.dirname(ggx)
      projects << proj  if is_ggx_project?(proj)
    end
    projects
  end

  #----------
  # Build a connect string for Sybase that mimics Discovery
  # UID=dba;PWD=sql;DBF='\\DEN1GGX06\e$\Alabama\Deep Water/gxdb.db';
  # DBN=Deep_Water-Alabama;HOST=DEN1GGX06;Server=GGX_DEN1GGX06
  def self.connect_string(proj)
    host =  parse_host(proj)
    dbn = "#{File.basename(proj)}-#{parse_home(proj)}".gsub(" ","_")

    conn = []
    conn << "UID=dba"
    conn << "PWD=sql"
    conn << "DBF='#{File.join(proj,'gxdb.db')}'"
    conn << "DBN=#{dbn}"
    conn << "HOST=#{host}"
    conn << "Server=GGX_#{host}"
    conn.join(";")
  end

  private

  #----------
  # Simple check for database and Global AOI dir
  def self.is_ggx_project?(path) 
    a = File.join(path, "gxdb.db")
    b = File.join(path, "Global")
    return (File.exists?(a) && File.exists?(b)) ? true : false
  end

  #----------
  # Pluck the hostname from either the UNC path or local host.
  # Replace backslashes with forward slashes for consistency
  def self.parse_host(proj)
    proj = proj.gsub("\\","/")
    project_server = (proj.match /^\/\//) ? 
      (proj.match /^\/\/(\w+)/)[1] : Socket.gethostname
  end

  #----------
  # Try to get home name from home.ini first; assume parent otherwise
  def self.parse_home(proj)
    ini = File.join(File.dirname(proj), "home.ini")
    m = File.read(ini).match /Name=(.*)/
    m[1] ? m[1] : File.basename(File.dirname(proj))
  end


=begin
    def total_bytes(path)
      dir = File.join(path, "**/*")
      Dir.glob(dir, File::FNM_DOTMATCH).select{|f| File.file?(f)}.map do |j|
        if File.exists?(j) && File.readable?(j)
          File.stat(j).size ||= 0
        else
          puts "COULD NOT READ  #{j}"
          0
        end
      end.inject(:+)
    end
=end

end

