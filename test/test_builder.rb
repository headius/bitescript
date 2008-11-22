require 'test/unit'
require 'jvmscript/builder'

class TestBuilder < Test::Unit::TestCase
  JLong = java.lang.Long
  JString = java.lang.String
  System = java.lang.System
  
  def new_class_name
    "Foo" + (System.nano_time + rand(JLong::MAX_VALUE)).to_s
  end

  def setup
    @builder = JVMScript::FileBuilder.build('somefile.source')
    @class_name = new_class_name
  end

  def dummy_constructor(class_builder)
    class_builder.public_constructor do
      aload local 'this'
      invokespecial object, '<init>', [void]
      returnvoid
    end
  end

  def load_and_construct(name, class_builder)
    class_bytes = class_builder.generate
    cls = JRuby.runtime.jruby_class_loader.define_class(name, class_bytes.to_java_bytes)

    cls.new_instance
  end

  def load(name, builder)
    bytes = builder.generate
    JRuby.runtime.jruby_class_loader.define_class(name, bytes.to_java_bytes)
    JavaUtilities.get_proxy_class(name)
  end

  def try(return_type, &b)
    class_name = new_class_name
    cb = @builder.public_class(class_name, @builder.object);
    cb.public_static_method("foo", return_type, &b)
    dummy_constructor(cb)
    cls = load(class_name, cb)
    cls.foo
  end

  def test_static_method
    assert_equal 'ok', try(JString) {ldc 'ok'; areturn}
  end

  def test_field_ops
    # TODO
  end

  def test_sync_ops
    # TODO figure out what's wrong with this and add error cases
    assert_equal 'ok', try(JString) {
      after = label
      ldc 'ok'
      astore 0
      ldc 'ok'
      astore 1
      aload 0
#      monitorenter
      label :begin
      ldc 'ok'
      astore 1
      goto after
      label :finally
      pop
      aload 0
#      monitorexit
      label :end
      trycatch(:begin, :finally, :finally, nil)
      trycatch(:finally, :end, :finally, nil)
      after.set!
      aload 1
      areturn
    }
  end

  def test_stack_ops
    # TODO
  end

  def test_constants
    assert_equal false, try(Java::boolean) {ldc false; ireturn}
    assert_equal 1, try(Java::byte) {ldc 1; ireturn}
    assert_equal 1, try(Java::short) {ldc 1; ireturn}
    assert_equal 1, try(Java::char) {ldc 1; ireturn}
    assert_equal 1, try(Java::int) {ldc 1; ireturn}
    assert_equal 1, try(Java::long) {ldc_long 1; lreturn}
    assert_equal 1.0, try(Java::float) {ldc_float 1.0; freturn}
    assert_equal 1.0, try(Java::double) {ldc 1.0; dreturn}
    assert_equal 'foo', try(JString) {ldc 'foo'; areturn}

    assert_equal(-1, try(Java::int) {iconst_m1; ireturn})
    assert_equal 0, try(Java::int) {iconst_0; ireturn}
    assert_equal 1, try(Java::int) {iconst_1; ireturn}
    assert_equal 2, try(Java::int) {iconst_2; ireturn}
    assert_equal 3, try(Java::int) {iconst_3; ireturn}
    assert_equal 4, try(Java::int) {iconst_4; ireturn}
    assert_equal 5, try(Java::int) {iconst_5; ireturn}
    assert_equal 0, try(Java::long) {lconst_0; lreturn}
    assert_equal 1, try(Java::long) {lconst_1; lreturn}
    assert_equal 0.0, try(Java::float) {fconst_0; freturn}
    assert_equal 1.0, try(Java::float) {fconst_1; freturn}
    assert_equal 2.0, try(Java::float) {fconst_2; freturn}
    assert_equal 0.0, try(Java::double) {dconst_0; dreturn}
    assert_equal 1.0, try(Java::double) {dconst_1; dreturn}
    assert_equal nil, try(JString) {aconst_null; areturn}
  end

  def test_math
    assert_equal 2, try(Java::int) {ldc 1; ldc 1; iadd; ireturn}
    assert_equal 0, try(Java::int) {ldc 1; ldc 1; isub; ireturn}
    assert_equal 4, try(Java::int) {ldc 2; ldc 2; imul; ireturn}
    assert_equal 2, try(Java::int) {ldc 4; ldc 2; idiv; ireturn}
    assert_equal 2, try(Java::int) {ldc 1; ldc 1; iadd; ireturn}
    assert_equal 2, try(Java::int) {ldc 1; istore 0; iinc 0, 1; iload 0; ireturn}
    assert_equal 0, try(Java::int) {ldc 1; istore 0; iinc 0, -1; iload 0; ireturn}
    assert_equal 5, try(Java::int) {ldc 1; ldc 4; ior; ireturn}
    assert_equal 5, try(Java::int) {ldc 7; ldc 13; iand; ireturn}
    assert_equal 5, try(Java::int) {ldc 10; ldc 15; ixor; ireturn}
    assert_equal(-5, try(Java::int) {ldc 5; ineg; ireturn})
    assert_equal(2147483643, try(Java::int) {ldc(-10); ldc 1; iushr; ireturn})
    assert_equal(-5, try(Java::int) {ldc(-10); ldc 1; ishr; ireturn})
    assert_equal(8, try(Java::int) {ldc 4; ldc 1; ishl; ireturn})
    assert_equal(3, try(Java::int) {ldc 15; ldc 4; irem; ireturn})

    assert_equal 2, try(Java::long) {ldc_long 1; ldc_long 1; ladd; lreturn}
    assert_equal 0, try(Java::long) {ldc_long 1; ldc_long 1; lsub; lreturn}
    assert_equal 4, try(Java::long) {ldc_long 2; ldc_long 2; lmul; lreturn}
    assert_equal 2, try(Java::long) {ldc_long 4; ldc_long 2; ldiv; lreturn}
    assert_equal 5, try(Java::long) {ldc_long 1; ldc_long 4; lor; lreturn}
    assert_equal 5, try(Java::long) {ldc_long 7; ldc_long 13; land; lreturn}
    assert_equal 5, try(Java::long) {ldc_long 10; ldc_long 15; lxor; lreturn}
    assert_equal(-5, try(Java::long) {ldc_long 5; lneg; lreturn})
    assert_equal(9223372036854775803, try(Java::long) {ldc_long(-10); ldc 1; lushr; lreturn})
    assert_equal(-5, try(Java::long) {ldc_long(-10); ldc 1; lshr; lreturn})
    assert_equal(8, try(Java::long) {ldc_long 4; ldc 1; lshl; lreturn})
    assert_equal(3, try(Java::long) {ldc_long 15; ldc_long 4; lrem; lreturn})

    assert_equal 2.0, try(Java::float) {ldc_float 1; ldc_float 1; fadd; freturn}
    assert_equal 0.0, try(Java::float) {ldc_float 1; ldc_float 1; fsub; freturn}
    assert_equal 4.0, try(Java::float) {ldc_float 2; ldc_float 2; fmul; freturn}
    assert_equal 2.0, try(Java::float) {ldc_float 4; ldc_float 2; fdiv; freturn}
    assert_equal(-5.0, try(Java::float) {ldc_float 5; fneg; freturn})
    assert_equal(3.0, try(Java::float) {ldc_float 15; ldc_float 4; frem; freturn})

    assert_equal 2.0, try(Java::double) {ldc_double 1; ldc_double 1; dadd; dreturn}
    assert_equal 0.0, try(Java::double) {ldc_double 1; ldc_double 1; dsub; dreturn}
    assert_equal 4.0, try(Java::double) {ldc_double 2; ldc_double 2; dmul; dreturn}
    assert_equal 2.0, try(Java::double) {ldc_double 4; ldc_double 2; ddiv; dreturn}
    assert_equal(-5.0, try(Java::double) {ldc_double 5; dneg; dreturn})
    assert_equal(3.0, try(Java::double) {ldc_double 15; ldc_double 4; drem; dreturn})
  end

  def test_trycatch
    assert_equal 2, try(Java::int) {
      label :begin
      new java.lang.Exception
      dup
      invokespecial java.lang.Exception, '<init>', [void]
      athrow
      label :catch
      ldc 2
      ireturn
      label :end
      trycatch(:begin, :catch, :catch, java.lang.Exception)
    }
  end

  def test_jumps
    assert_equal 2, try(Java::int) {after = label; goto after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 0; ifeq after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 1; ifne after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc -1; iflt after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 1; ifgt after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; aconst_null; ifnull after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; getstatic System, 'out', java.io.PrintStream; ifnonnull after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; aconst_null; aconst_null; if_acmpeq after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; aconst_null; getstatic System, 'out', java.io.PrintStream; if_acmpne after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 1; ldc 2; if_icmplt after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 1; ldc 1; if_icmple after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 2; ldc 1; if_icmpgt after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    assert_equal 2, try(Java::int) {after = label; ldc 2; ldc 2; if_icmpge after; ldc 1; ireturn; after.set!; ldc 2; ireturn}
    # TODO: jsr and ret
  end

  def test_multianewaray
    # TODO
  end

  def test_switches
    assert_equal 3, try(Java::int) {
      one, two, three, four, default = label, label, label, label, label
      ldc 3
      lookupswitch default, [1,2,3,4], [one, two, three, four]
      one.set!; ldc 1; ireturn
      two.set!; ldc 2; ireturn
      three.set!; ldc 3; ireturn
      four.set!; ldc 4; ireturn
      default.set!; ldc 0; ireturn
    }
    assert_equal 3, try(Java::int) {
      one, two, three, four, default = label, label, label, label, label
      ldc 3
      tableswitch 1, 4, default, [one, two, three, four]
      one.set!; ldc 1; ireturn
      two.set!; ldc 2; ireturn
      three.set!; ldc 3; ireturn
      four.set!; ldc 4; ireturn
      default.set!; ldc 0; ireturn
    }
  end

  def test_casts
    assert_equal 1.0, try(Java::float) {ldc 1; i2f; freturn}
    assert_equal 1, try(Java::int) {ldc_float 1.0; f2i; ireturn}

    assert_equal 1.0, try(Java::double) {ldc 1; i2d; dreturn}
    assert_equal 1, try(Java::int) {ldc 1.0; d2i; ireturn}

    assert_equal -1, try(Java::int) {ldc_long java.lang.Long::MAX_VALUE; l2i; ireturn}
    assert_equal 2147483648, try(Java::long) {ldc java.lang.Integer::MAX_VALUE; i2l; ldc_long 1; ladd; lreturn}
    
    assert_equal 9.223372036854776e+18, try(Java::float) {ldc_long java.lang.Long::MAX_VALUE; l2f; freturn}
    assert_equal -9223372036854775808, try(Java::long) {ldc_float java.lang.Float::MAX_VALUE; f2l; ldc_long 1; ladd; lreturn}

    assert_equal 9.223372036854776e+18, try(Java::double) {ldc_long java.lang.Long::MAX_VALUE; l2d; dreturn}
    assert_equal -9223372036854775808, try(Java::long) {ldc java.lang.Double::MAX_VALUE; d2l; ldc_long 1; ladd; lreturn}
  end

  def test_locals
    assert_equal true, try(Java::boolean) {ldc true; istore 0; iload 0; ireturn}
    assert_equal 1, try(Java::int) {ldc 1; istore 0; iload 0; ireturn}
    assert_equal 1, try(Java::long) {ldc_long 1; lstore 0; lload 0; lreturn}
    assert_equal 1.0, try(Java::float) {ldc_float 1.0; fstore 0; fload 0; freturn}
    assert_equal 1.0, try(Java::double) {ldc_double 1.0; dstore 0; dload 0; dreturn}
    assert_equal 'foo', try(JString) {ldc 'foo'; astore 0; aload 0; areturn}
  end

  def test_instance_method_this
    cb = @builder.public_class(@class_name, @builder.object);
    method = cb.public_method("foo", cb.this) {aload local 'this'; areturn}

    # ensure "this" is taking slot zero
    method.local('another')
    assert_equal(method.local('this'), 0)
    assert_equal(method.local('another'), 1)

    dummy_constructor(cb)
    obj = load_and_construct(@class_name, cb)

    assert_equal(obj, obj.foo)
  end

  def test_constructor_this
    cb = @builder.public_class(@class_name, @builder.object);
    cb.private_field "self", cb.this
    constructor = cb.public_constructor do
      aload 0
      dup
      invokespecial object, "<init>", [void]
      dup
      putfield this, "self", this
      returnvoid
    end

    cb.public_method "get_self", cb.this do
      aload 0
      getfield this, "self", this
      areturn
    end

    # ensure "this" is taking slot zero
    constructor.local('another')
    assert_equal(constructor.local('this'), 0)
    assert_equal(constructor.local('another'), 1)

    obj = load_and_construct(@class_name, cb)
    assert_equal(obj, obj.get_self)
  end

  def test_native_method
    cb = @builder.public_class(@class_name, @builder.object);
    
    body_called = false
    cb.public_native_method("yoohoo") {body_called = true}

    assert !body_called

    dummy_constructor(cb)
    obj = load_and_construct(@class_name, cb);
    
    # expect NativeException (UnsatisfiedLinkError)
    assert_raises(NativeException) {obj.yoohoo}
  end

  def test_fields
    cb = @builder.public_class(@class_name, @builder.object);

    cb.public_field('inst_field', JString)
    cb.public_static_field('static_field', JString)

    cb.public_method('set_inst', cb.void) {aload 0; ldc 'instance'; putfield this, 'inst_field', JString; returnvoid}
    cb.public_method('set_static', cb.void) {ldc 'static'; putstatic this, 'static_field', JString; returnvoid}
    cb.public_method('get_inst', JString) {aload 0; getfield this, 'inst_field', JString; areturn}
    cb.public_method('get_static', JString) {getstatic this, 'static_field', JString; areturn}

    dummy_constructor(cb)
    obj = load_and_construct(@class_name, cb);

    assert_equal nil, obj.get_inst
    assert_equal nil, obj.get_static
    obj.set_inst
    obj.set_static
    assert_equal 'instance', obj.get_inst
    assert_equal 'static', obj.get_static
  end

  def test_arrays
    cb = @builder.public_class(@class_name, @builder.object);

    cb.public_method("newbooleanarray", cb.boolean[]) {ldc 5; newbooleanarray; dup; ldc 1; ldc true; bastore; dup; dup; ldc 2; swap; ldc 1; baload; bastore; areturn}
    cb.public_method("newbytearray", cb.byte[]) {ldc 5; newbytearray; dup; ldc 1; ldc 1; bastore; dup; dup; ldc 2; swap; ldc 1; baload; bastore; areturn}
    cb.public_method("newshortarray", cb.short[]) {ldc 5; newshortarray; dup; ldc 1; ldc 1; sastore; dup; dup; ldc 2; swap; ldc 1; saload; sastore; areturn}
    cb.public_method("newchararray", cb.char[]) {ldc 5; newchararray; dup; ldc 1; ldc 1; castore; dup; dup; ldc 2; swap; ldc 1; caload; castore; areturn}
    cb.public_method("newintarray", cb.int[]) {ldc 5; newintarray; dup; ldc 1; ldc 1; iastore; dup; dup; ldc 2; swap; ldc 1; iaload; iastore; areturn}
    cb.public_method("newlongarray", cb.long[]) {ldc 5; newlongarray; dup; ldc 1; ldc_long 1; lastore; dup; dup; ldc 2; swap; ldc 1; laload; lastore; areturn}
    cb.public_method("newfloatarray", cb.float[]) {ldc 5; newfloatarray; dup; ldc 1; ldc_float 1.0; fastore; dup; dup; ldc 2; swap; ldc 1; faload; fastore; areturn}
    cb.public_method("newdoublearray", cb.double[]) {ldc 5; newdoublearray; dup; ldc 1; ldc 1.0; dastore; dup; dup; ldc 2; swap; ldc 1; daload; dastore; areturn}
    cb.public_method("anewarray", cb.string[]) {ldc 5; anewarray JString; dup; ldc 1; ldc 'foo'; aastore; dup; dup; ldc 2; swap; ldc 1; aaload; aastore; areturn}

    dummy_constructor(cb)
    obj = load_and_construct(@class_name, cb);
    
    ary = obj.newbooleanarray
    assert_equal(Java::boolean.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([false,true,true,false,false], ary.to_a)

    ary = obj.newbytearray
    assert_equal(Java::byte.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,1,1,0,0], ary.to_a)

    ary = obj.newshortarray
    assert_equal(Java::short.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,1,1,0,0], ary.to_a)

    ary = obj.newchararray
    assert_equal(Java::char.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,1,1,0,0], ary.to_a)

    ary = obj.newintarray
    assert_equal(Java::int.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,1,1,0,0], ary.to_a)

    ary = obj.newlongarray
    assert_equal(Java::long.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,1,1,0,0], ary.to_a)

    ary = obj.newfloatarray
    assert_equal(Java::float.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0.0,1.0,1.0,0.0,0.0], ary.to_a)

    ary = obj.newdoublearray
    assert_equal(Java::double.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0.0,1.0,1.0,0.0,0.0], ary.to_a)

    ary = obj.anewarray
    assert_equal(java.lang.String.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([nil,'foo','foo',nil,nil], ary.to_a)

    assert_equal 5, try(Java::int) {ldc 5; newintarray; arraylength; ireturn}
  end
end
