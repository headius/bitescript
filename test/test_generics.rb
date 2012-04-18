$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'bitescript'

class TestGenerics < Test::Unit::TestCase
  def test_type_signature
    sig = BiteScript::GenericTypeBuilder.read('Ljava/util/List<TE;>;')
    assert sig.generic_class?
    assert_equal 'Ljava/util/List;', sig.raw_type.descriptor
    assert_kind_of BiteScript::ASM::Type, sig.raw_type
    assert_equal 1, sig.type_arguments.size
    assert sig.type_arguments[0].type_variable?
    assert_equal 'E', sig.type_arguments[0].name
  end

  def test_wildcard
    sig = BiteScript::GenericTypeBuilder.read('Ljava/util/List<*>;')
    assert sig.generic_class?
    assert_equal 'Ljava/util/List;', sig.raw_type.descriptor
    assert_kind_of BiteScript::ASM::Type, sig.raw_type
    assert_equal 1, sig.type_arguments.size
    assert sig.type_arguments[0].wildcard?

    wildcard = sig.type_arguments[0]
    assert_nil wildcard.lower_bound
    assert_not_nil wildcard.upper_bound
    assert_equal 'Ljava/lang/Object;', wildcard.upper_bound.descriptor

    sig = BiteScript::GenericTypeBuilder.read('Ljava/util/List<+Ljava/lang/Number;>;')
    wildcard = sig.type_arguments[0]
    assert wildcard.wildcard?
    assert_nil wildcard.lower_bound
    assert_not_nil wildcard.upper_bound
    assert_equal 'Ljava/lang/Number;', wildcard.upper_bound.descriptor

    sig = BiteScript::GenericTypeBuilder.read('Ljava/util/List<-Ljava/lang/Integer;>;')
    wildcard = sig.type_arguments[0]
    assert wildcard.wildcard?
    assert_not_nil wildcard.lower_bound
    assert_nil wildcard.upper_bound
    assert_equal 'Ljava/lang/Integer;', wildcard.lower_bound.descriptor
  end

  def test_array
    sig = BiteScript::GenericTypeBuilder.read('[Ljava/util/List<Ljava/lang/String;>;')
    assert sig.array?
    list = sig.component_type
    assert list.generic_class?
    assert_equal 'Ljava/util/List;', list.raw_type.descriptor
    assert_kind_of BiteScript::ASM::Type, list.raw_type
    assert_equal 1, list.type_arguments.size
    string = list.type_arguments[0]
    assert_equal 'Ljava/lang/String;', string.descriptor
  end

  def test_inner_class
    sig = BiteScript::GenericTypeBuilder.read('Ljava/util/HashMap<TK;TV;>.HashIterator<TK;>;')
    assert sig.generic_class?
    assert_kind_of BiteScript::ASM::Type, sig.raw_type
    assert_equal 'Ljava/util/HashMap$HashIterator;', sig.raw_type.descriptor
    assert sig.outer_type.generic_class?
    assert_kind_of BiteScript::ASM::Type, sig.outer_type.raw_type
    assert_equal 'Ljava/util/HashMap;', sig.outer_type.raw_type.descriptor
    assert_equal ['K', 'V'], sig.outer_type.type_arguments.map {|x| x.name}
  end

  def test_method_signature
    sig = BiteScript::SignatureMirror.new(
        '<T:Ljava/lang/Object;>(I)Ljava/lang/Class<+TT;>;')
    assert sig.method?
    assert !sig.class?

    type = sig.return_type
    assert type.generic_class?
    assert_equal 'Ljava/lang/Class;', type.raw_type.descriptor
    assert_equal 1, type.type_arguments.size

    arg = type.type_arguments[0]
    assert arg.wildcard?
    assert_nil arg.lower_bound
    assert_not_nil arg.upper_bound
    assert arg.upper_bound.type_variable?
    assert_equal 'T', arg.upper_bound.name

    assert_equal 1, sig.parameter_types.size
    assert_kind_of BiteScript::ASM::Type, sig.parameter_types[0]
    assert_equal 'I', sig.parameter_types[0].descriptor

    assert_equal 1, sig.type_parameters.size
    var = sig.type_parameters[0]
    assert var.type_variable?
    assert_equal 'T', var.name
    assert_equal 1, var.bounds.size
    assert_equal 'Ljava/lang/Object;', var.bounds[0].descriptor
  end

  def test_class_signature
    sig = BiteScript::SignatureMirror.new(
        '<E:Ljava/lang/Object;>Ljava/util/List<TE;>;')
    assert sig.class?
    assert !sig.method?

    assert_equal 0, sig.interfaces.size

    superclass = sig.superclass
    assert superclass.generic_class?
    assert_equal 'Ljava/util/List;', superclass.raw_type.descriptor
    assert_equal 'E', superclass.type_arguments[0].name

    assert_equal 1, sig.type_parameters.size
    var = sig.type_parameters[0]
    assert var.type_variable?
    assert_equal 'E', var.name
    assert_equal 1, var.bounds.size
    assert_equal 'Ljava/lang/Object;', var.bounds[0].descriptor
  end

  def test_multiple_bounds
    sig = BiteScript::SignatureMirror.new(
        '<T::Ljava/lang/Comparable<TT;>;:Ljava/lang/Iterable<TT;>;>Ljava/lang/Object;')
    t = sig.type_parameters[0]
    assert_equal 2, t.bounds.size
    assert_equal "java.lang.Comparable<T>", t.bounds[0].to_s
    assert_equal "java.lang.Iterable<T>", t.bounds[1].to_s
  end
  
  def test_generic_parameter_types
    mirror = BiteScript::ClassMirror.load('java.util.ArrayList')
    method = mirror.getDeclaredMethods('add')[0]
    assert_not_nil method.generic_parameter_types
    puts method.generic_parameter_types
    
  end
end
