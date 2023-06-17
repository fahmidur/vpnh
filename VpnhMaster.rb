class VpnhMaster
  require 'time'
  require_relative 'Util'
  require_relative 'ConfigFile'
  require_relative 'VpnhConfig'
  require_relative 'VpnhServer'
  require_relative 'VpnhClient'
  require_relative 'Ovpns'
  require_relative 'Auths'
  require_relative 'IpAddr'

  attr_reader :the_path

  def initialize
    @status_prev = {}
  end

  def version
    return @version if @version
    version_path = File.join(__dir__, 'VERSION')
    return nil unless File.exists?(version_path)
    @version = semver_read(version_path)
    return @version
  end

  def config
    @config ||= VpnhConfig.new(con_path)
  end

  def server_daemon
    Util.daemonize do
      self.server.ignition
    end
  end

  def server_daemon_ensure
    if server_running?
      puts "a server is already running"
      return
    end
    if server_ponging?
      puts "a server is already ponging"
      return
    end
    self.server_daemon
  end

  def disconnect
    pid = openvpn_pid
    if pid && Util.process_exists?(pid)
      puts "Sending SIGTERM to openvpn process at pid=#{pid}"
      Process.kill(15, pid)
    end
    # config.set(:autoconnect, false)
    return true
  end

  def get_xip_real
    addr = IpAddr.new(Util.run("curl -s -m 10 ifconfig.me").out)
    return nil unless addr.valid?
    return addr
  end

  def get_xip_virt
    vpnh_user = config.get(:vpnh_user)
    addr = IpAddr.new(Util.run("sudo -u #{vpnh_user} curl -s -m 10 ifconfig.me").out)
    return nil unless addr.valid?
    return addr
  end

  def openvpn_running?(pid=nil)
    pid = openvpn_pid unless pid
    return pid if pid && Util.process_exists?(pid)
    return nil
  end

  def status(from=nil)
    out = {}
    out[:xip_real] = get_xip_real
    out[:xip_virt] = get_xip_virt
    out[:openvpn_pid] = openvpn_pid
    out[:openvpn_running] = openvpn_running?(out[:openvpn_pid])
    out[:autoconnect] = config.get(:autoconnect)
    unless from == :server
      out[:server_pid] = server_pid
      out[:server_running] = server_running?(out[:server_pid])
      out[:server_ponging] = server_ponging?
    end
    out[:connected] = !!(
      out[:openvpn_running] && 
      out[:xip_virt] && 
      out[:xip_real] && 
      out[:xip_real] != out[:xip_virt]
    )
    connected_curr = out[:connected]
    connected_prev = !!(@status_prev[:connected])
    if connected_curr != connected_prev 
      if connected_curr 
        # transitioned from disconnected -> connected 
        # out[:connected_count] = (@status_prev[:connected_count] || 0)+1
        out[:connected_at] = Time.now
      else
        # transitioned from connected -> disconnected
        # out[:disconnected_count] = (@status_prev[:disconnected_count] || 0)+1
        out[:disconnected_at] = Time.now
      end
    end
    @status_prev = out
    return out
  end

  def auto_connectable?
    return !!(
      config.is_valid? &&
      config.get(:autoconnect) &&
      config.get(:ovpn_sel)
    )
  end

  def reconnect(name=nil)
    disconnect
    sleep 5
    connect(name)
  end

  def connect(name=nil)
    pid = openvpn_pid
    if pid && Util.process_exists?(pid)
      puts "ERROR: openvpn already running at pid=#{pid}"
      return false
    end
    pids = Util.pgrep("openvpn")
    if pids && pids.size > 0
      puts "ERROR: another openvpn is still running. pids=#{pids}"
      return false
    end
    unless name
      puts "getting last ovpn_sel"
      name = config.get(:ovpn_sel)
      puts "fetched last ovpn_sel=#{name}" if name
    end
    unless name
      puts "ERROR: ovpn name required"
      return false
    end
    ovpn_path = self.ovpns.get_path(name)
    unless ovpn_path
      puts "no such ovpn with name=#{name}"
      return false
    end
    if openvpn_prelocked?
      puts "ERROR: openvpn_prelocked. another connect/openvpn is taking place"
      return false
    end
    openvpn_prelock_acquire
    config.set(:autoconnect, true)
    config.set(:ovpn_sel, name)
    puts "openvpn. starting..."
    com = Util.run("openvpn --config #{ovpn_path} --writepid #{openvpn_pid_path} --verb 4 --daemon")
    puts "openvpn. start_ed... DONE"
    openvpn_prelock_release
    return com.success?
  end

  def openvpn_prelock_path
    @openvpn_prelock_path ||= File.join(the_path, 'openvpn_prelock')
  end
  def openvpn_prelocked?
    File.exists?(openvpn_prelock_path)
  end
  def openvpn_prelock_acquire
    IO.write(openvpn_prelock_path, Time.now.to_i.to_s)
  end
  def openvpn_prelock_release
    return unless File.exists?(openvpn_prelock_path)
    FileUtils.rm_f(openvpn_prelock_path)
  end

  def openvpn_pid
    if File.exists?(openvpn_pid_path)
      return IO.read(openvpn_pid_path).strip.to_i
    end
    return Util.pgrep("openvpn").first
  end

  def openvpn_pid_path
    @openvpn_pid_path ||= File.join(the_path, 'openvpn.pid')
  end

  def semver_read(path)
    return [-1, -1, -1] unless File.exists?(path)
    IO.read(path).strip.split('.')[0..2].map(&:to_i)
  end

  def auths_path
    @auths_path ||= File.join(the_path, 'auths')
  end

  def auths
    @auths ||= Auths.new(self, self.auths_path)
  end

  def ovpns_path
    @ovpns_path ||= File.join(the_path, 'ovpns')
  end

  def ovpns
    @ovpns ||= Ovpns.new(self, self.ovpns_path)
  end

  def client
    @client ||= VpnhClient.new(self)
  end

  def server
    @server ||= VpnhServer.new(self)
  end

  def the_path
    return @the_path if @the_path
    @the_path = '/opt/vpnh'
    Util.dir_ensure(@the_path)
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

  def server_pid
    return nil unless File.exists?(pid_path)
    return IO.read(pid_path).strip.to_i
  end

  def server_running?(pid=nil)
    pid = server_pid unless pid
    return pid if pid && Util.process_exists?(pid)
    return nil
  end

  def server_ponging?
    return client.ponging?
  end

  # must succeed before ovpn_up
  # IDEMPOTENT
  def setup
    unless Util.sys_write_ok?
      puts "sys_write denied"
      return false
    end

    errors = []
    vpnh_user = config.get(:vpnh_user)
    vpnh_tabl = config.get(:vpnh_tabl)
    real_iface = config.get(:real_iface)
    errors << 'expecting config.vpnh_user'  unless vpnh_user
    errors << 'expecting config.vpnh_tabl'  unless vpnh_tabl
    errors << 'expecting config.real_iface' unless real_iface
    return false if in_error?(errors)

    #--- { create vpnh_user { # IDEMPOTENT
    puts "VpnhMaster. setup. making user=#{vpnh_user}"
    Util.user_add(vpnh_user)
    unless Util.user_exists?(vpnh_user)
      puts "ERROR: failed to make vpnh_user=#{vpnh_user}" 
      return false
    end
    #---

    #--- { make vpnh_table { IDEMPOTENT
    puts "VpnhMaster. setup. making tabl=#{vpnh_tabl}"
    Util.routing_table_add(vpnh_tabl) #idempotent
    unless Util.routing_table_exists?(vpnh_tabl)
      puts "ERROR: failed to make vpnh_table=#{vpnh_tabl}"
      return false
    end
    #--- } make vpnh_table }
    
    #--- { block vpnh_user from using real_iface { IDEMPOTENT
    puts "VpnhMaster. setup. iptables block user=#{vpnh_user} from iface=#{real_iface}"
    unless Util.iptables_add("OUTPUT", "-o #{real_iface} -m owner --uid-owner #{vpnh_user} -j REJECT")
      puts "ERROR: iptables_add failed"
      return false
    end
    #--- } block vpnh_user from using real_iface  }

    return true
  end

  def in_error?(errors)
    if errors.size > 0
      puts "VpnhMaster. errors:"
      errors.each {|err| puts "* #{err}" }
    end
    return errors.size > 0
  end

  def co_vpnh_path
    return File.join(co_path, "vpnh")
  end

  def co_ovpn_up_path
    return File.join(co_path, "vpnh_ovpn_up")
  end

  def co_ovpn_down_path
    return File.join(co_path, "vpnh_ovpn_down")
  end

  def co_path
    return @co_path if @co_path
    path = File.join(the_path, "co")
    FileUtils.mkdir_p(path) unless Dir.exists?(path)
    return (@co_path = path)
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
    vpnh_user  = config.vpnh_user
    vpnh_tabl  = config.vpnh_tabl
    real_iface = config.real_iface
    #---
    unless self.setup() # idempotent
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
    FileUtils.rm_f(openvpn_pid_path) if File.exists?(openvpn_pid_path)
    return true
  end

end

