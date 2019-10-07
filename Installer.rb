module Installer
  require_relative 'Util'

  THE_PATH = '/var/opt/vpnh'
  TCO_PATH = '/var/opt/vpnh/co'

  def self.install
    puts "THE_PATH=#{THE_PATH}"
    puts "TCO_PATH=#{TCO_PATH}"
  end

end
