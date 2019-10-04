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

  def add(filepath, name: nil, auth: nil)
    unless File.exists?(filepath)
      puts "ERROR: no such file at #{filepath}"
      return false
    end
    name = SecureRandom.hex unless name
    unless name =~ /^[a-zA-Z0-9_\.\-]+$/
      puts "ERROR: invalid name #{name}"
      return false
    end
    auth_path = auth ? @master.auths.get_path(auth) : nil
    if auth && !auth_path
      puts "ERROR: unable to find auth_path from auth"
      return false
    end
    new_filename = name_to_filename(name)
    new_filepath = File.join(@path, new_filename)
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
      olines << "script-security 3 system"
      olines << "up #{@master.co_ovpn_up_path}"
      olines << "down #{@master.co_ovpn_down_path}"
      if auth_path
        olines << "auth-user-pass #{auth_path}"
      end
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
    filepath = get_path(name)
    return nil unless filepath
    data = _parse_ovpn_file(filepath) || {}
    data[:name] = name
    return data
  end

  def get_path(name)
    filename = name_to_filename(name)
    return nil unless filename
    filepath = File.join(@path, filename)
    return nil unless File.exists?(filepath)
    return filepath
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
      if line =~ /auth-user-pass (.+)$/
        ret[:auth_user_pass] = $1.strip
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
