class VpnhMaster
  require_relative 'Util'
  require_relative 'ConfigFile'
  require_relative 'VpnhConfig'
  require_relative 'VpnhServer'
  require_relative 'VpnhClient'

  attr_reader :the_path

  def initialize
    @config = VpnhConfig.new(con_path)
  end

  def config
    @config
  end

  def client
    @client ||= VpnhClient.new(self)
  end

  def server
    @server ||= VpnhServer.new(self)
  end

  def the_path
    return @the_path if @the_path
    @the_path = '/var/opt/vpnh'
    unless Dir.exists?(@the_path)
      FileUtils.mkdir(@the_path)
    end
    return @the_path
  end

  def pid_path
    @pid_path ||= File.join(the_path, 'lock.pid');
  end

  def ipc_path
    @ipc_path ||= File.join(the_path, 'ipc.sock');
  end

  def con_path
    @con_path ||= File.join(the_path, 'config.json');
  end

  def running_server_pid
    return nil unless File.exists?(pid_path)
    existing_pid = IO.read(pid_path).strip.to_i
    if existing_pid && Util.process_exists?(existing_pid)
      return existing_pid
    end
    return nil
  end

  def setup
    vpnh_user = @config.get(:vpnh_user)
    if vpnh_user
      puts "VpnhMaster. setup. making user=#{vpnh_user}"
      Util.user_add(vpnh_user)
    end
    vpnh_tabl = @config.get(:vpnh_tabl)
    if vpnh_tabl
      puts "VpnhMaster. setup. making tabl=#{vpnh_tabl}"
      Util.routing_table_add(vpnh_tabl)
    end
  end

  def ovpn_up(virt_iface, virt_iface_addr)
    errors = []
    unless virt_iface
      errors << "expecting argument virt_iface"
    end
    unless virt_iface_addr
      errors << "expecting argument virt_iface_addr"
    end
    if errors.size > 0
      puts "VpnhMster. ovpn_up. errors:"
      error.each {|err| puts "* #{err}" }
      return false
    end
    vpnh_user = @config.vpnh_user
    vpnh_tabl = @config.vpnh_tabl
    unless vpnh_user
      errors << "expecting config.vpnh_user"
    end
    unless vpnh_tabl
      errors << "expecting config.vpnh_tabl"
    end
    if errors.size > 0
      puts "VpnhMster. ovpn_up. errors:"
      errorr.each {|err| puts "* #{err}" }
      return false
    end
    self.setup
    unless Util.routing_table_exists?(vpnh_tabl)
      errors << "failed to create routing_table #{vpnh_tabl}"
    end
    unless Util.user_exists?(vpnh_tabl)
      errors << "failed to create user #{vpnh_user}"
    end
    if errors.size > 0
      puts "VpnhMster. ovpn_up. errors:"
      errors.each {|err| puts "* #{err}" }
      return false
    end
  end

  def ovpn_down(virt_iface, virt_iface_addr)
    errors = []
    unless virt_iface
      errors << "expecting argument virt_iface"
    end
    unless virt_iface_addr
      errors << "expecting argument virt_iface_addr"
    end
    if errors.size > 0
      puts "VpnhMster. ovpn_down. errors:"
      error.each {|err| puts "* #{err}" }
      return false
    end
  end

end

