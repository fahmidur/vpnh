# Delegates to the VpnhServer object via DRb. 
# Ensures that the VpnhServer remote
# object is connected.
class VpnhClient
  require 'drb'

  def initialize(master)
    @master = master
    @server = nil
  end

  def method_missing(meth, *args, &block)
    connect
    if @server && @server.respond_to?(meth)
      @server.public_send(meth, *args, &block)
    end
  end

  def server_running?
    connect
    return false unless @server
    return @server.running?
  end

  def status
    connect
    return {
      :state => :not_running
    } unless @server
    return @server.status
  end

  private

  def connect
    return if @server
    if @master.running_server_pid && File.exists?(@master.ipc_path)
      @server = DRbObject.new_with_uri("drbunix://#{@master.ipc_path}")
    end
  end
end

