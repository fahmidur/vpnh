module Util
  require 'set'

  def self.ami_root?
    Process.euid == 0
  end

  def self.get_all_users
    Set.new(IO.read('/etc/passwd').split("\n").map {|e| e.split(':')[0] })
  end

  def self.user_exists?(name)
    users = get_all_users
    users.member?(name)
  end

  def self.get_all_ifaces
    ifaces = Set.new
    `ip link show`.split("\n").each do |line|
      next unless line =~ /^\d+: ([a-zA-Z0-9_]+)/
      ifaces << $1
    end
    return ifaces
  end

  def self.get_default_iface
    `netstat -r`.split("\n").each do |line|
      next unless line =~ /^default\b/
      return (line.split(/\s+/)[7].chomp)
    end
    return nil
  end

  def self.daemonize
    raise 'fork failed' if (pid=fork) == -1
    exit if pid != nil # exit the parent process
    Process.setsid # child becomes new session and group leader
    raise 'second fork failed' if (pid=fork) == -1
    exit if pid != nil
    daemon_pid = pid
    Dir.chdir '/'
    File.umask 0000
    STDIN.reopen '/dev/null'
    STDOUT.reopen '/dev/null'
    STDERR.reopen '/dev/null'
    yield
  end
  
  def self.process_exists?(pid)
    !!Process.kill(0, pid) rescue false
  end

end
