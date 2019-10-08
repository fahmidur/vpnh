module Util
  require 'set'
  require 'ostruct'
  require 'fileutils'

  class Command
    attr_reader :return
    attr_reader :stdout
    def initialize(command)
      puts "Command < #{command}"
      @stdout = `#{command}`
      @return = $?
      self.stdout_puts
      puts "Command > excode=#{self.excode}"
    end
    def out
      @stdout.strip
    end
    def stdout_puts
      return unless self.stdout_present?
      print @stdout
      puts unless @stdout[-1] == "\n"
    end
    def stdout_present?
      @stdout && @stdout !~ /^\s*$/
    end
    def excode
      @return.exitstatus
    end
    def each_line
      self.lines.each do |line|
        yield line
      end
    end
    def lines
      @stdout.strip.split("\n")
    end
    def success?
      @return.exitstatus == 0
    end
    def failure?
      @return.exitstatus != 0
    end
  end


  def self.package_install(name)
    puts "package_install. installing #{name} ..."
    if Util.which("apt-get")
      puts "packag_install. found apt-get"
      Util.run("apt-get install -y #{name}")
      return true
    end
    puts "package_install. unable to find package-manger"
    return false
  end

  def self.package_ensure(name)
    if Util.which(name)
      puts "package_ensure. #{name} already installed"
      return true
    end
    return Util.package_install(name)
  end

  def self.shellrc_path_add(shellrc_path, path_item)
    unless File.exists?(shellrc_path)
      puts "shellrc_path_add. no such file at #{shellrc_path}"
      return false
    end
    new_line = "export PATH=$PATH:#{path_item} #VPNH_INSTALL"
    already_installed = false
    File.open(shellrc_path) do |f|
      f.each_line do |line|
        line = line.strip
        if line == new_line
          puts "shellrc_path_add. already installed. --SKIPPED"
          already_installed = true
          break
        end
      end
    end
    return true if already_installed
    puts "shellrc_path_add. appending to PATH within #{shellrc_path}..."
    File.open(shellrc_path, 'a') do |f|
      f.puts(new_line)
    end
    puts "--- done"
    return true
  end

  def self.dir_ensure(path)
    if Dir.exists?(path)
      puts "dir_ensure. dir already exists. path=#{path} "
      return true
    end
    puts "dir_ensure. making path=#{path}"
    FileUtils.mkdir_p(path)
    return true
  end

  def self.dir_remake(path)
    if Dir.exists?(path)
      puts "dir_remake. removing path=#{path}"
      FileUtils.rm_rf(path) 
    end
    puts "dir_remake. remaking path=#{path}"
    FileUtils.mkdir_p(path)
    return true
  end

  def self.which(prog_name)
    com = Command.new("which #{prog_name}")
    return nil unless com.out.size > 0
    return com.out
  end

  def self.ip_rule_del_m(table_name)
    rules_to_del = []
    unless table_name
      puts "ERROR: ip_rule_del_m. expecting table_name"
      return false
    end
    Util.run("ip rule show").each_line do |line|
      line.chomp!
      next unless line =~ /^(\d+):\s+(.+)$/
      priority = $1
      rule = $2
      if rule =~ /\b#{table_name}\b/
        rules_to_del << rule
      end
    end
    rules_to_del.each do |rule|
      puts "ip_rule_del_m. deleting rule: |#{rule}|"
      Util.run("ip rule del #{rule}")
    end
    return true
  end

  def self.iptables_has(chain, rule_spec)
    iptables_path = Util.which("iptables")
    unless iptables_path
      puts "ERROR: unable to find iptables_path"
      return false
    end
    com = Command.new("#{iptables_path} -C #{chain} #{rule_spec}")
    return com.excode == 0
  end

  def self.iptables_add(chain, rule_spec, idem=true)
    iptables_path = Util.which("iptables")
    unless iptables_path
      puts "ERROR: unable to find iptables_path"
      return false
    end
    if idem && Util.iptables_has(chain, rule_spec)
      puts "iptables. chain=#{chain} rule_spec=#{rule_spec} already exists. --- SKIPPED"
      return true
    end
    com = Command.new("#{iptables_path} -A #{chain} #{rule_spec}")
    return com
  end

  def self.run(command)
    return Command.new(command)
  end

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
    path = '/etc/machine-id'
    return nil unless File.exists?(path)
    return IO.read(path).strip
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
  
  def self.pifile_pid(path)
    return nil unless File.exists?(path)
    pid = IO.read(path).strip.split("\n")[0].strip.to_i
    return pid
  end

  def self.pidfile_active_pid(path)
    pid = Util.pidfile_pid(path)
    return pid if pid && Util.process_exists?(pid)
    return nil
  end
  
  def self.process_exists?(pid)
    !!Process.kill(0, pid) rescue false
  end

end
