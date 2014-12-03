require "sequel"
require "tiny_tds"
require "awesome_print"
require "yaml"

class MSSQL

  opts = YAML.load_file("./settings.yml")[:sql_server]

  @db = Sequel.connect(
    adapter: "tinytds",
    host: opts[:host],
    database: opts[:database]
  )

  at_exit { @db.disconnect if @db }

  def self.create_table(table_name, block)
    ap "creating table: #{table_name}..."
    @db.create_table table_name.to_sym, &block
  end

  def self.drop_table(table_name)
    ap "dropping table: #{table_name}..."
    @db.drop_table table_name.to_sym
  end

  def self.empty_table(table_name)
    ap "delete all rows from: #{table_name}..."
    ap @db[table_name.to_sym].delete
  end

  def self.write_data(table_name, data)
    fail "sql data should be an array" unless data.class == Array
    ap "writing #{data.size} rows..."
    @db[table_name.to_sym].multi_insert data
  end

  def self.read_data(table_name)
    ap "listing contents for #{table_name}..."
    ap @db[table_name.to_sym].all
  end

end

