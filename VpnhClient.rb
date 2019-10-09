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
    return nil
  end

  private

  def connect
    return if @server
    if @master.server_running? && File.exists?(@master.ipc_path)
      @server = DRbObject.new_with_uri("drbunix://#{@master.ipc_path}")
    end
  end
end

