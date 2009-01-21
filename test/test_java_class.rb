$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'bitescript'

class TestJavaClass < Test::Unit::TestCase
  def test_constructor
    cls = java.lang.String.java_class

    cons1 = cls.constructor()
    cons2 = cls.constructor(java.lang.String.java_class)

    assert_not_nil cons1
    assert_not_nil cons2
    assert_equal [], cons1.parameter_types
    assert_equal [java.lang.String.java_class], cons2.parameter_types

    cls = BiteScript::FileBuilder.new('x').public_class('y')
    cls.public_constructor()
    cls.public_constructor(java.lang.String.java_class)

    cons1 = cls.constructor()
    cons2 = cls.constructor(java.lang.String.java_class)

    assert_not_nil cons1
    assert_not_nil cons2
    assert_equal [], cons1.parameter_types
    assert_equal [java.lang.String.java_class], cons2.parameter_types
  end

  def test_java_method
    cls = java.lang.String.java_class
    
    m1 = cls.java_method("toString")
    m2 = cls.java_method("equals", java.lang.Object.java_class)

    assert_not_nil m1
    assert_not_nil m2
    assert_equal java.lang.String.java_class, m1.return_type
    assert_equal Java::boolean.java_class, m2.return_type
    assert_equal [], m1.parameter_types
    assert_equal [java.lang.Object.java_class], m2.parameter_types

    cls = BiteScript::FileBuilder.new('x').public_class('y')
    cls.public_method('toString', java.lang.String.java_class)
    cls.public_method('equals', Java::boolean.java_class, java.lang.Object.java_class)

    m1 = cls.java_method('toString')
    m2 = cls.java_method('equals', java.lang.Object.java_class)
    
    assert_not_nil m1
    assert_not_nil m2
    assert_equal java.lang.String.java_class, m1.return_type
    assert_equal Java::boolean.java_class, m2.return_type
    assert_equal [], m1.parameter_types
    assert_equal [java.lang.Object.java_class], m2.parameter_types
  end
end
