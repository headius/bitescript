$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'jvmscript'

class TestJavaClass < Test::Unit::TestCase
  def test_constructor
    cls = java.lang.String.java_class

    cons1 = cls.constructor()
    cons2 = cls.constructor(java.lang.String.java_class)

    assert_not_nil cons1
    assert_not_nil cons2

    cls = JVMScript::FileBuilder.new('x').public_class("y")
    cls.public_constructor()
    cls.public_constructor(java.lang.String.java_class)

    cons1 = cls.constructor()
    cons2 = cls.constructor(java.lang.String.java_class)

    assert_not_nil cons1
    assert_not_nil cons2
  end
end
