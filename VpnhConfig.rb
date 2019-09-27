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
    if val == nil
      @config.set(Util.get_default_iface)
      return
    end
    # TODO ensure that val is a valid iface
    @config.set(val)
  end

end
