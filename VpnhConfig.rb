class VpnhConfig
  require_relative 'Util'
  attr_reader :errors

  def initialize(conthing)
    case conthing
    when String
      @confile = ConfigFile.new(conthing)
    when ConfigFile
      @confile = conthing
    else
      raise 'invalid conthing'
    end
    @props = Set.new([
      'real_iface', 
      'vpnh_user', 
      'vpnh_tabl', 
      'autoconnect',
      'ovpn_sel',
    ])
    default!
    @errors = []
    validate!
  end

  def default!
    @confile.with_wlock do
      self.set(:vpnh_user, 'vpnh_user') unless self.get(:vpnh_user)
      self.set(:vpnh_tabl, 'vpnh_tabl') unless self.get(:vpnh_tabl)
      self.real_iface_default!
      if @confile.get(:autoconnect) == nil
        self.autoconnect = false
      end
    end
    validate!
    return true
  end

  def validate!
    @errors = []
    unless self.real_iface
      @errors << 'real_iface is required'
    end
    unless self.vpnh_user
      @errors << 'vpnh_user is required'
    end
    unless self.vpnh_tabl
      @errors << 'vpnh_tabl is required'
    end
  end
  
  def is_valid?
    @errors.size == 0
  end

  def to_h
    @props.inject({}) do |h,k|
      h[k] = self.get(k)
      h
    end
  end

  def get(key)
    key = key.to_s
    return nil unless is_prop?(key)
    return self.public_send(key) if self.respond_to?(key)
    return @confile.get(key)
  end

  def data_read_lazy
    @confile.data_read_lazy
  end

  def method_missing(meth, *args, &block)
    return self.get(meth)
  end

  def set(key, val)
    key = key.to_s
    unless is_prop?(key)
      puts "WARNING: invalid property #{key}"
      return nil 
    end
    setter_meth = (key + '=').to_sym
    if self.respond_to?(setter_meth)
      self.public_send(setter_meth, val)
    else
      @confile.set(key, val)
    end
    validate!
    return get(key)
  end

  def is_prop?(key)
    @props.member?(key.to_s)
  end

  def autoconnect=(bool)
    puts "autconnect=#{bool}(#{bool.class})"
    @confile.set(:autoconnect, _fix_bool(bool))
  end

  def real_iface=(val)
    return real_iface_default! unless val
    all_ifaces = Util.get_all_ifaces
    unless all_ifaces.member?(val)
      puts "WARNING: #{val} is not a valid iface"
    end
    @confile.set(:real_iface, val)
    validate!
    return real_iface
  end

  def real_iface_default!
    return if @confile.get(:real_iface)
    default_iface = Util.get_default_iface
    unless default_iface
      puts "WARNING: unable to determine default_iface"
      return nil
    end
    @confile.set(:real_iface, default_iface)
    validate!
    return real_iface
  end

  def _fix_bool(bool)
    #puts "_fix_bool. bool=#{bool}(#{bool.class})"
    return bool if bool == !!bool
    if bool.is_a?(String)
      return false if bool =~ /^\s*false\s*$/i
      return true  if bool =~ /^\s*true\s*$/i
    end
    puts "WARNING: _fix_bool. expecting boolean. bool=#{bool}(#{bool.class})"
    return nil
  end

end
