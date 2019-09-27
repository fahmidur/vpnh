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

end

