class IpAddr
  attr_reader :bytes
  attr_reader :error

  def initialize(thing)
    @bytes = []
    @dotmap = {}
    @error = nil
    if thing.is_a?(String)
      thing = thing.strip
      if thing =~ /^(\d+)\.(\d+)\.(\d+)\.(\d+)$/
        # ipv4 quad notation
        @bytes = [$1.to_i, $2.to_i, $3.to_i, $4.to_i]
      elsif thing =~ /([0-9a-f]{4}):([0-9a-f]{4}):([0-9a-f]{4}):([0-9a-f]{4}):([0-9a-f]{4}):([0-9a-f]{4}):([0-9a-f]{4}):([0-9a-f]{4})/i
        @bytes = [$1, $2, $3, $4, $5, $6, $7, $8].map {|s| s.scan(/../).map(&:hex) }.flatten
      else
        @error = 'invalid string initializer'
      end
    elsif thing.is_a?(IpAddr)
      @bytes = thing.bytes.clone
    elsif thing.is_a?(Array)
      @bytes = thing
    else
      @error = "invalid argument class"
    end
    unless @bytes.size == 4 || @bytes.size == 16
      @error = 'expecting 4 or 16 bytes'
    end
  end

  def valid?
    @error == nil
  end

  def cidr(n)
    "#{self.to_s}/#{n}"
  end

  def dot1
    self.dot(1)
  end

  def dot0
    self.dot(0)
  end

  def to_s
    return @bytes.join(".") if @bytes.size == 4
    return @bytes.map{|e| e.to_s(16).rjust(2, '0') }.each_slice(2).map{|e| e.join }.join(':')
  end

  def dot(num)
    return @dotmap[num] if @dotmap[num]
    @dotmap ||= {}
    bytes = @bytes.clone
    bytes[-1] = num
    return (@dotmap[num] = IpAddr.new(bytes))
  end

  def <=>(other)
    return self.to_s <=> other.to_s
  end
end
