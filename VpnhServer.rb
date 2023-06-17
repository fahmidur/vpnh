class VpnhServer
  require 'drb'

  def initialize(master)
    @master = master
    @mainloop_go = true
    @t1 = nil
  end

  def ignition
    if (existing_pid=@master.server_running?)
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

  def ponging?
    return {
      :pid => Process.pid,
      :now => Time.now.to_i
    }
  end

  def time
    return Time.now
  end

  def t1_kill
    return unless @t1
    puts "killing t1..."
    Thread.kill(@t1)
  end

  def get_default_iface
    Util.get_default_iface
  end

  def config_update
    puts "config_update. updating..."
    @master.config.data_read_lazy
  end

  private
  
  def mainloop
    FileUtils.rm_f(@master.ipc_path) if File.exists?(@master.ipc_path)
    DRb.start_service("drbunix://#{@master.ipc_path}", self)
    @t1 = Thread.new {
      connect_fail_count = 0
      while(@mainloop_go)
        puts "========================================"
        self.config_update
        st = @master.status(:server)
        puts "status=\n#{JSON.pretty_generate(st)}\n"
        if st[:connected]
          puts "already connected. -SKIP-"
        else 
          if @master.auto_connectable?
            puts "auto_connectable. connecting..."
            ok = @master.connect
            unless ok
              connect_fail_count += 1
              puts "auto_connectable. Connect FAILURE. connect_fail_count=#{connect_fail_count}"
              if connect_fail_count > 3
                puts "auto_connectable. Connect. Something is wrong, trying reconnect ..."
                connect_fail_count = 0
                master.reconnect
              end
            end
          else
            puts "NOT auto_connectable. -SKIP-"
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
