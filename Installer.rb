module Installer
  require 'fileutils'
  require_relative 'Util'

  THE_PATH          = '/var/opt/vpnh'
  TCO_PATH          = File.join(THE_PATH, 'co')
  VPNH_PATH         = File.join(TCO_PATH, 'vpnh')
  VPNH_SERVICE_NAME = 'vpnh.service'
  VPNH_SERVICE_PATH = File.join(TCO_PATH, VPNH_SERVICE_NAME)
  VPNH_PID_PATH     = File.join(TCO_PATH, 'lock.pid')
  OPENVPN_PID_PATH  = File.join(TCO_PATH, 'openvpn.pid')

  def self.install
  end

  def self.uninstall(purge: false)
    if Util.which("systemctl")
      puts "systemctl. stopping / disabling service"
      Util.run("systemctl stop #{VPNH_SERVICE_NAME}")
      Util.run("systemctl --force disable #{VPNH_SERVICE_NAME}")
      Util.run("systemctl daemon-reload")
    else
      puts "manually stopping vpnh ..."
      Util.run("#{VPNH_PATH} stop")
    end
    while pid=Util.pidfile_active_pid(VPNH_PID_PATH)
      puts "Waiting for vpnh server to exit... pid=#{pid}"
      sleep 1
    end
    puts "Killing openvpn..."
    Util.run("pkill openvpn")
    while pid=Util.pidfile_active_pid(OPENVPN_PID_PATH)
      puts "Waiting for openvpn to exit... pid=#{pid}"
      sleep 1
    end
    FileUtils.rm_rf(TCO_PATH)
    if purge
      puts "purging..."
      puts "removing THE_PATH=#{THE_PATH}"
      FileUtils.rm_rf(THE_PATH)
    end
  end

end
