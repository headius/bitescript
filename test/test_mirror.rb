require 'test/unit'
require 'bitescript'

class TestMirror < Test::Unit::TestCase
  def test_simple_mirror
    object_mirror = BiteScript::ASM::ClassMirror.load('java.lang.Object')
    
    equals = object_mirror.getDeclaredMethods('equals')[0]
    assert_equal 'equals', equals.name
    assert_equal ['java.lang.Object'], equals.parameter_types.map(&:class_name)
  end
end