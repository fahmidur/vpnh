class VpnhConfig
  require_relative 'Util'

  def initialize(conthing)
    case conthing
    when String
      @confile = ConfigFile.new(conthing)
    when ConfigFile
      @confile = conthing
    else
      raise 'invalid conthing'
    end
    @props = Set.new(['real_iface'])
  end

  def get(key)
    key = key.to_s
    return nil unless is_prop?(key)
    return self.public_send(key) if self.respond_to?(key)
    return @confile.get(key)
  end

  def set(key, val)
    key = key.to_s
    unless is_prop?(key)
      puts "WARNING: invalid property #{key}"
      return nil 
    end
    setter_meth = (key + '=').to_sym
    return self.public_send(setter_meth, val) if self.respond_to?(setter_meth)
    return @confile.set(key, val)
  end

  def is_prop?(key)
    @props.member?(key.to_s)
  end

  def real_iface; @confile.get('real_iface'); end;
  def real_iface=(val)
    if val
      all_ifaces = Util.get_all_ifaces
      unless all_ifaces.member?(val)
        puts "WARNING: #{val} is not a valid iface"
      end
      @confile.set(:real_iface, val)
      return real_iface
    else
      default_iface = Util.get_default_iface
      unless default_iface
        puts "WARNING: unable to determine default_iface"
      end
      @confile.set(:real_iface, default_iface)
      return real_iface
    end
  end

end
