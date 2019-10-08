class VpnhServer
  require 'drb'

  def initialize(master)
    @master = master
    @mainloop_go = true
    @t1 = nil
  end

  def ignition
    if (existing_pid=@master.running_server_pid)
      raise "Another VpnhServer is already running at PID=#{existing_pid}"
    end
    IO.write(@master.pid_path, "#{Process.pid}\n")
    trap("TERM") do
      puts "\n--- Heard SIGTERM ---"
      shutdown
    end
    trap("INT") do
      puts "\n--- Heard SIGINT ---"
      shutdown
    end
    mainloop
  end

  def shutdown
    @mainloop_go = false
    pid = File.exists?(@master.pid_path) ? IO.read(@master.pid_path).strip.to_i : nil
    return unless pid
    return Process.kill(15, pid) unless pid == Process.pid
    FileUtils.rm_f(@master.pid_path)
    DRb.stop_service
  end

  def running?
    return true
  end

  def time
    return Time.now
  end

  def t1_kill
    return unless @t1
    $logger.info "killing t1..."
    Thread.kill(@t1)
  end

  def get_default_iface
    Util.get_default_iface
  end

  def config_update
    $logger.info "config_update. updating..."
    @master.config.data_read_lazy
  end

  private
  
  def mainloop
    FileUtils.rm_f(@master.ipc_path) if File.exists?(@master.ipc_path)
    DRb.start_service("drbunix://#{@master.ipc_path}", self)
    @t1 = Thread.new {
      while(@mainloop_go)
        $logger.info "+===---===---+"
        self.config_update
        st = @master.status(:server)
        $logger.info "status=\n#{JSON.pretty_generate(st)}\n"
        if st[:connected]
          $logger.info "already connected. -SKIP-"
        else 
          if @master.auto_connectable?
            $logger.info "auto_connectable. connecting..."
            @master.connect
          else
            $logger.info "NOT autoconnectable. -SKIP-"
          end
        end
        sleep 15
      end
    }
    begin
    DRb.thread.join
    rescue
    ensure
      DRb.stop_service
    end
    shutdown
  end
end
