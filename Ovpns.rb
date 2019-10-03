class Ovpns
  require 'fileutils'
  require 'securerandom'
  def initialize(master, path)
    @master = master
    @path = path
    FileUtils.mkdir_p(path) unless Dir.exists?(path)
  end

  def all
    out = {}
    Dir.entries(@path).each do |filename|
      next if filename == "." || filename == ".."
      next unless filename =~ /^(.+)\.ovpn$/
      id = $1
      out[id] = self.get(id)
    end
    return out
  end

  def add(filepath)
    unless File.exists?(filepath)
      puts "ERROR: no such file at #{filepath}"
      return false
    end
    id = SecureRandom.hex
    new_filename = id_to_filename(id)
    new_filepath = File.join(@path, new_filename)
    # TODO:
    # ensure route-nopull
    # add the up/down scripts
    # add user/pass if provided
    FileUtils.cp(filepath, new_filepath)
    return true
  end

  def del(id)
    filename = id_to_filename(id)
    filepath = File.join(@path, filename)
    unless File.exists?(filepath)
      puts "no such ovpn file with id=#{id}"
      return true
    end
    FileUtils.rm(filepath)
    return true
  end

  def get(id)
    filename = id_to_filename(id)
    filepath = File.join(@path, filename)
    return nil unless File.exists?(filepath)
    data = _parse_ovpn_file(filepath) || {}
    data[:id] = id
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

  def id_to_filename(id)
    "#{id}.ovpn"
  end

end
