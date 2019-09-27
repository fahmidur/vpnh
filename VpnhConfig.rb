class VpnhConfig
  require_relative 'Util'

  def initialize(conthing)
    case conthing
    when String
      @config = ConfigFile.new(conthing)
    when ConfigFile
      @config = conthing
    else
      raise 'invalid conthing'
    end
  end

  def real_iface=(val)
    if val
      all_ifaces = Util.get_all_ifaces
      unless all_ifaces.member?(val)
        puts "WARNING: #{val} is not a valid iface"
      end
      @config.set(val)
    else
      default_iface = Util.get_default_iface
      unless default_iface
        puts "WARNING: unable to determine default_iface"
      end
      @config.set(default_iface)
      return
    end
  end

end
