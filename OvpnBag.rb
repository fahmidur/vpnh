class OvpnBag
  require 'fileutils'
  require 'securerandom'
  def initialize(master, path)
    @master = master
    @path = path
    FileUtils.mkdir_p(path) unless Dir.exists?(path)
  end

  def add(filepath)
    id = SecureRandom.hex
    new_filename = id_to_filename(id)
    new_filepath = File.join(@path, new_filename)
    # TODO:
    # ensure route-nopull
    # add the up/down scripts
    # add user/pass if provided
    FileUtils.cp(filepath, new_filepath)
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

  def id_to_filename(id)
    "#{id}.ovpn"
  end

end
