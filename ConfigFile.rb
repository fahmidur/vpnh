# A class to represent JSON persisted
# configuration files.
class ConfigFile
  require 'json'
  def initialize(file_path)
    @file_path = file_path
    raise 'expecting file_path' unless @file_path
    @data_read = {}
    @data_write_lock = false
    @data = {}
    data_read
    data_write_lazy
  end

  def get(key)
    @data[key.to_s]
  end

  def with_wlock
    data_write_lock_acquire
    yield
    data_write_lock_release
    data_write_lazy
  end

  def data_write_lock_acquire
    @data_write_lock = true
  end

  def data_write_lock_release
    @data_write_lock = false
  end

  def set(key, val)
    key = key.to_s
    if val == nil
      @data.delete(key)
    else
      @data[key] = val
    end
    data_write_lazy
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
    return if @data_write_lock
    #$logger.info "VpnhConfig. data_write ..."
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

  def data_write_lazy
    return unless changed?
    self.data_write
  end

end
