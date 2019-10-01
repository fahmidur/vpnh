require 'test/unit'
require_relative 'IpAddr'

class IpAddrTest < Test::Unit::TestCase
  def test_ipv4_001
    addr_str = '192.168.1.5'
    addr = IpAddr.new(addr_str)
    assert_equal(addr_str, addr.to_s)
    assert_equal('192.168.1.1', addr.dot1.to_s)
    assert_equal('192.168.1.0', addr.dot0.to_s)
    assert_equal('192.168.1.5/24', addr.cidr(24))
    assert_equal('192.168.1.5/32', addr.cidr(32))
    assert_equal('192.168.1.0/24', addr.dot0.cidr(24))
  end

  def test_invalid_001
    addr = IpAddr.new('foobar')
    assert_equal(false, addr.valid?)
  end
end
