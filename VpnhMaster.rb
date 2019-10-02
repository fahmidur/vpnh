class VpnhMaster
  require_relative 'Util'
  require_relative 'ConfigFile'
  require_relative 'VpnhConfig'
  require_relative 'VpnhServer'
  require_relative 'VpnhClient'
  require_relative 'IpAddr'

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

  # must succeed before ovpn_up
  def setup
    unless Util.sys_write_ok?
      puts "sys_write denied"
      return false
    end
    errors = []
    vpnh_user = @config.get(:vpnh_user)
    vpnh_tabl = @config.get(:vpnh_tabl)
    real_iface = @config.get(:real_iface)
    errors << 'expecting config.vpnh_user'  unless vpnh_user
    errors << 'expecting config.vpnh_tabl'  unless vpnh_tabl
    errors << 'expecting config.real_iface' unless real_iface
    return false if in_error?(errors)
    # make vpnh_user
    puts "VpnhMaster. setup. making user=#{vpnh_user}"
    Util.user_add(vpnh_user) # idempotent
    unless Util.user_exists?(vpnh_user)
      puts "ERROR: failed to make vpnh_user=#{vpnh_user}" 
      return false
    end
    # make vpnh_table
    puts "VpnhMaster. setup. making tabl=#{vpnh_tabl}"
    Util.routing_table_add(vpnh_tabl) #idempotent
    unless Util.routing_table_exists?(vpnh_tabl)
      puts "ERROR: failed to make vpnh_table=#{vpnh_tabl}"
      return false
    end
    # block vpnh_user from using real_iface
    puts "VpnhMaster. setup. iptables block user=#{vpnh_user} from iface=#{real_iface}"
    unless Util.iptables_add("OUTPUT", "-o #{real_iface} -m owner --uid-owner #{vpnh_user} -j REJECT")
      puts "ERROR: iptables_add failed"
      return false
    end
    return true
  end

  def in_error?(errors)
    if errors.size > 0
      puts "VpnhMaster. errors:"
      errors.each {|err| puts "* #{err}" }
    end
    return errors.size > 0
  end

  def ovpn_up(virt_iface, virt_iface_addr)
    unless Util.sys_write_ok?
      puts "sys_write denied"
      return false
    end
    #---
    errors = []
    errors << "expecting argument virt_iface" unless virt_iface
    errors << "expecting argument virt_iface_addr" unless virt_iface_addr
    return false if in_error?(errors)
    #---
    virt_iface_addr = IpAddr.new(virt_iface_addr)
    unless virt_iface_addr.valid?
      puts "ERROR: invalid virt_iface_addr=#{virt_iface_addr}"
      return false
    end
    #---
    vpnh_user  = @config.vpnh_user
    vpnh_tabl  = @config.vpnh_tabl
    real_iface = @config.real_iface
    #---
    unless self.setup
      puts "ERROR: setup failed"
      return false
    end
    #---
    Util.run("ip route add #{virt_iface_addr.dot0.cidr(24)} dev #{virt_iface} src #{virt_iface_addr} table #{vpnh_tabl}")
    Util.run("ip route add default via #{virt_iface_addr.dot1} dev #{virt_iface} table #{vpnh_tabl}")
    Util.ip_rule_del_m(vpnh_tabl) # delete old ip rules
    Util.run("ip rule add from #{virt_iface_addr.cidr(32)} table #{vpnh_tabl}")
    Util.run("ip rule add to #{virt_iface_addr.cidr(32)} table #{vpnh_tabl}")
    vpnh_user_id = Util.run("id -u #{vpnh_user}").out.to_i
    unless vpnh_user_id
      puts "ERROR: failed to get user id of vpnh_user=#{vpnh_user}"
      return false
    end
    puts "adding ip rule uidrange for vpnh_user..."
    Util.run("ip rule add uidrange #{vpnh_user_id}-#{vpnh_user_id} lookup #{vpnh_tabl}")
    puts "--- done"
    return true
  end

  def ovpn_down(virt_iface, virt_iface_addr)
    unless Util.sys_write_ok?
      puts "sys_write denied"
      return false
    end
    errors = []
    errors << "expecting argument virt_iface" unless virt_iface
    errors << "expecting argument virt_iface_addr" unless virt_iface_addr
    return false if in_error?(errors)
    return true
  end

end

