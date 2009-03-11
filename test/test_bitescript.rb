$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'bitescript'

class TestBitescript < Test::Unit::TestCase
  def test_bytecode_version
    assert_equal BiteScript::JAVA1_4, BiteScript.bytecode_version
    [BiteScript::JAVA1_4, BiteScript::JAVA1_5, BiteScript::JAVA1_6].each do |ver|
      BiteScript.bytecode_version = ver
      assert_equal(ver, BiteScript.bytecode_version)
    end
  end
end
