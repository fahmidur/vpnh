class Auths
  require 'fileutils'
  require 'securerandom'
  require 'ostruct'

  def initialize(master, path)
    @master = master
    @path = path
    FileUtils.mkdir_p(@path) unless Dir.exists?(@path)
  end

  def flush
    self.all.each do |name, val|
      next unless name
      self.del(name)
    end
  end

  def all
    out = {}
    Dir.entries(@path).each do |name|
      next if name == "." || name == ".."
      next unless name =~ /^\w+$/
      out[name] = self.get(name)
    end
    return out
  end

  def get(name)
    path = name_to_path(name)
    return nil unless File.exists?(path)
    user, pass = IO.read(path).strip.split("\n")
    return {
      :user => user,
      :pass => pass,
    }
  end

  def del(name)
    path = name_to_path(name)
    unless File.exists?(path)
      puts "WARNING: no such auth name=#{name} path=#{path}"
      return true
    end
    begin
      FileUtils.rm(path)
    rescue
      puts "ERROR: failed to remove path=#{path}"
      return false
    end
    return true
  end

  def add(user, pass, name=nil)
    name = SecureRandom.hex unless name
    unless name =~ /\w+/
      puts "ERROR: invalid name"
      return false
    end
    unless user && pass
      puts "ERROR: expecting user and pass"
      return false
    end
    if user.index("\n")
      puts "ERROR: user cannot contain newline"
      return false
    end
    if pass.index("\n")
      puts "ERROR: pass cannot contain newline"
      return false
    end
    IO.write(name_to_path(name), "#{user}\n#{pass}")
    return name
  end

  def get_path(name)
    data = self.get(name)
    return nil unless data
    return name_to_path(name)
  end

  def name_to_path(name)
    File.join(@path, name)
  end

end
