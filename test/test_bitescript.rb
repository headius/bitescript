$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'bitescript'

class TestBitescript < Test::Unit::TestCase
  def test_bytecode_defaults_to_current_version
    spec_version = ENV_JAVA['java.specification.version']
    expected_version = BiteScript.const_get("JAVA#{spec_version.gsub('.', '_')}")

    assert_equal expected_version, BiteScript.bytecode_version
  end

  def test_bytecode_version
    
    [BiteScript::JAVA1_4, BiteScript::JAVA1_5, BiteScript::JAVA1_6].each do |ver|
      BiteScript.bytecode_version = ver
      assert_equal(ver, BiteScript.bytecode_version)
    end
  end
end
