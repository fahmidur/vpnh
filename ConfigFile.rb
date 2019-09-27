# A class to represent JSON persisted
# configuration files.
class ConfigFile
  require 'json'
  def initialize(file_path)
    @file_path = file_path
    raise 'expecting file_path' unless @file_path
    @data_read = {}
    @data = {}
    data_read
    data_write if changed?
  end

  def get(key)
    @data[key.to_s]
  end

  def set(key, val)
    if val
      @data.delete(key)
    else
      @data[key.to_s] = val
    end
    data_write if changed?
  end

  def data_read
    return unless File.exists?(@file_path)
    gdata = {}
    odata = JSON.parse(IO.read(@file_path))
    odata.each do |k, v|
      next if k[0] == '_'
      gdata[k] = v
    end
    @data_read = gdata.clone
    @data = gdata.clone
  end

  def data_write
    $logger.info "VpnhConfig. data_write ..."
    dirname = File.dirname(@file_path)
    FileUtils.mkdir_p(dirname)
    data = @data.clone
    data['_write_ts'] = Time.now.to_i
    json_str = JSON.pretty_generate(data)
    IO.write(@file_path, json_str+"\n")
    data_read
  end

  def changed?
    @data_read != @data || !File.exists?(@file_path)
  end

end
