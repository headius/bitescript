require 'test/unit'
require 'bitescript/mirror'

class TestMirror < Test::Unit::TestCase
  include BiteScript

  def test_varargs_true_on_varargs_method
    cmirror = ClassMirror.load 'java.lang.String'
    mmirror = cmirror.getDeclaredMethods('format').first
    assert mmirror.varargs?
  end

  def test_varargs_false_on_non_varargs_method
    cmirror = ClassMirror.load 'java.lang.String'
    mmirror = cmirror.getDeclaredMethods('copyValueOf').first
    assert_false mmirror.varargs?
  end

end
