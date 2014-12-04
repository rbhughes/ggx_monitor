require "sequel"
require "tiny_tds"
require "yaml"

class MSSQL

  def initialize(opts_path)
    opts = YAML.load_file(opts_path)[:sql_server]
    @db = Sequel.connect(
      adapter: "tinytds",
      host: opts[:host],
      database: opts[:database]
    )
  end

  at_exit { @db.disconnect if @db }

  def create_table(table_name, block)
    puts "creating table: #{table_name}..."
    @db.create_table table_name.to_sym, &block
  end

  def drop_table(table_name)
    puts "dropping table: #{table_name}..."
    @db.drop_table table_name.to_sym
  end

  def empty_table(table_name)
    puts "delete all rows from: #{table_name}..."
    puts @db[table_name.to_sym].delete
  end

  def write_data(table_name, data)
    fail "sql data should be an array" unless data.class == Array
    puts "writing #{data.size} row(s) to MSSQL..."
    @db[table_name.to_sym].multi_insert data
  end

  def read_data(table_name)
    puts "listing contents for #{table_name}..."
    puts @db[table_name.to_sym].all
  end

end

