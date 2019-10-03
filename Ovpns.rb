class Ovpns
  require 'fileutils'
  require 'securerandom'

  attr_reader :master
  attr_reader :path

  def initialize(master, path)
    @master = master
    @path = path
    FileUtils.mkdir_p(path) unless Dir.exists?(path)
  end

  def flush
    Dir.entries(@path).each do |filename|
      next if filename == "." || filename == ".."
      next unless filename =~ /^(.+)\.ovpn$/
      name = $1
      self.del(name)
    end
    return true
  end

  def all
    out = {}
    Dir.entries(@path).each do |filename|
      next if filename == "." || filename == ".."
      next unless filename =~ /^(.+)\.ovpn$/
      name = $1
      out[name] = self.get(name)
    end
    return out
  end

  def add(filepath, name=nil)
    unless File.exists?(filepath)
      puts "ERROR: no such file at #{filepath}"
      return false
    end
    name = SecureRandom.hex unless name
    unless name =~ /^[a-zA-Z0-9_\.\-]+$/
      puts "ERROR: invalid name #{name}"
      return false
    end
    new_filename = name_to_filename(name)
    new_filepath = File.join(@path, new_filename)
    # TODO:
    # ensure route-nopull
    # add the up/down scripts
    # add user/pass if provided
    #FileUtils.cp(filepath, new_filepath)
    olines = []
    file_open_success = false
    File.open(filepath) do |f|
      inside_vpnh = false
      f.each_line do |line|
        line.chomp!
        if line == '#vpnh{'
          inside_vpnh = true
          next
        end
        if line == '#vpnh}'
          inside_vpnh = false
          next
        end
        unless inside_vpnh
          olines << line
        end
      end
      # vpnh modifications
      olines << '#vpnh{'
      olines << 'route-nopull'
      olines << "up #{@master.co_ovpn_up_path}"
      olines << "down #{@master.co_ovpn_down_path}"
      olines << '#vpnh}'
      file_open_success = true
    end
    if file_open_success
      IO.write(new_filepath, olines.join("\n"))
    end
    return name
  end

  def del(name)
    filename = name_to_filename(name)
    filepath = File.join(@path, filename)
    unless File.exists?(filepath)
      puts "no such ovpn file with name=#{name}"
      return true
    end
    FileUtils.rm(filepath)
    return true
  end

  def get(name)
    filename = name_to_filename(name)
    filepath = File.join(@path, filename)
    return nil unless File.exists?(filepath)
    data = _parse_ovpn_file(filepath) || {}
    data[:name] = name
    return data
  end

  def _parse_ovpn_file(filepath)
    return nil unless File.exists?(filepath)
    ret = {}
    f = File.open(filepath)
    f.each_line do |line|
      line.gsub!(/#(.*)$/, '')
      next if line =~ /^\s*$/
      if line =~ /remote (.+)/
        host, port = $1.split(' ')
        ret[:remote] = {:host => host, :port => port}
      end
    end
    return ret
  ensure
    f.close if f
  end

  def name_to_filename(name)
    "#{name}.ovpn"
  end

end
