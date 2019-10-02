module Util
  require 'set'
  require 'ostruct'

  def self.ami_root?
    Process.euid == 0
  end

  def self.get_all_users
    Set.new(IO.read('/etc/passwd').split("\n").map {|e| e.split(':')[0] })
  end

  def self.user_exists?(username)
    users = get_all_users
    users.member?(username)
  end

  def self.user_add(username)
    unless Util.sys_write_ok?
      puts "user_add. sys_write denied"
      return nil
    end
    raise ArgumentError.new('expecting username') unless username
    raise ArgumentError.new('expecting string username') unless username.is_a?(String)
    raise ArgumentError.new('invalid username') unless username =~ /^\w+$/
    users = Util.get_all_users
    if users.member?(username)
      puts "user_add. user #{username} already exists. SKIPPED"
      return username
    end
    puts "user_add. adding user username=#{username}"
    res = `useradd -m #{username}`
    puts "user_add. useradd: #{res}"
    return username
  end

  def self.rt_tables_path
    '/etc/iproute2/rt_tables'
  end

  def self._rt_table_parseline(line)
    line.strip!
    line = line.gsub(/#+(.*)/, '')
    return nil if line.size == 0 || line =~ /^\s*$/
    fields = line.split(/\s+/)
    num = fields[0]
    str = fields[1]
    return nil unless str && str.size > 0
    return nil unless num && num.size > 0 
    num = num.to_i
    return OpenStruct.new({
      :str => str,
      :num => num,
    })
  end

  def self.get_routing_tables
    tables = {}
    f = File.open(Util.rt_tables_path)
    f.each_line do |line|
      data = self._rt_table_parseline(line)
      next unless data
      tables[data.str] = data.num
    end
    return tables
  ensure
    f.close if f
  end
  
  def self.routing_table_exists?(table_name)
    return Util.get_routing_tables.member?(table_name)
  end

  def self.routing_table_add(table_name)
    routing_tables = Util.get_routing_tables
    unless Util.sys_write_ok?
      puts "routing_table_add. sys_write denied"
      return
    end
    if routing_tables[table_name]
      puts "routing_table_add. #{table_name} already exists. SKIPPED"
      return
    end
    new_num = 1
    routing_table_nums = Set.new(routing_tables.values)
    while routing_table_nums.member?(new_num)
      new_num += 1
    end
    cnl = IO.read(Util.rt_tables_path)[-1] == "\n" ? "" : "\n"
    open(Util.rt_tables_path, 'a') do |f|
      f.puts "#{cnl}#{new_num}\t#{table_name}"
    end
  end

  def self.routing_table_del(table_name)
    routing_tables = Util.get_routing_tables
    unless Util.sys_write_ok?
      puts "routing_table_del. sys_write denied"
      return
    end
    unless routing_tables[table_name]
      puts "routing_table_del. #{table_name} does not exist. SKIPPED"
      return
    end
    rt_lines = []
    f = File.open(Util.rt_tables_path)
    f.each_line do |line|
      data = Util._rt_table_parseline(line)
      next if data && data.str == table_name
      rt_lines.push(line)
    end
    new_rt_table_body = rt_lines.join("\n")
    puts "--- beg. new rt_table body."
    puts new_rt_table_body
    puts "--- end. new rt_table_body."
    IO.write(Util.rt_tables_path, new_rt_table_body)
  ensure
    f.close if f
  end

  def self.get_machine_id
    IO.read('/etc/machine-id').strip
  end

  def self.sys_write_ok?
    return false if ENV['VPNH_NO_WRITE'] == '1'
    return false if Util.get_machine_id == 'b4fa03f9870a490183fc34a79efe6513'
    return true
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
