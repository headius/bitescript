require 'test/unit'
require 'jvmscript/builder'

class TestBuilder < Test::Unit::TestCase
  import java.util.ArrayList
  import java.lang.System
  
  def setup
    @builder = JVMScript::FileBuilder.build('somefile.source')
    @class_name = "Foo" + System.current_time_millis.to_s
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

  def test_newarray_methods
    cb = @builder.public_class(@class_name, @builder.object);

    cb.public_method("newbooleanarray", cb.boolean[]) {ldc 5; newbooleanarray; areturn}
    cb.public_method("newbytearray", cb.byte[]) {ldc 5; newbytearray; areturn}
    cb.public_method("newshortarray", cb.short[]) {ldc 5; newshortarray; areturn}
    cb.public_method("newchararray", cb.char[]) {ldc 5; newchararray; areturn}
    cb.public_method("newintarray", cb.int[]) {ldc 5; newintarray; areturn}
    cb.public_method("newlongarray", cb.long[]) {ldc 5; newlongarray; areturn}
    cb.public_method("newfloatarray", cb.float[]) {ldc 5; newfloatarray; areturn}
    cb.public_method("newdoublearray", cb.double[]) {ldc 5; newdoublearray; areturn}

    dummy_constructor(cb)
    obj = load_and_construct(@class_name, cb);
    
    ary = obj.newbooleanarray
    assert_equal(Java::boolean.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([false,false,false,false,false], ary.to_a)

    ary = obj.newbytearray
    assert_equal(Java::byte.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,0,0,0,0], ary.to_a)

    ary = obj.newshortarray
    assert_equal(Java::short.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,0,0,0,0], ary.to_a)

    ary = obj.newchararray
    assert_equal(Java::char.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,0,0,0,0], ary.to_a)

    ary = obj.newintarray
    assert_equal(Java::int.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,0,0,0,0], ary.to_a)

    ary = obj.newlongarray
    assert_equal(Java::long.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0,0,0,0,0], ary.to_a)

    ary = obj.newfloatarray
    assert_equal(Java::float.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0.0,0.0,0.0,0.0,0.0], ary.to_a)

    ary = obj.newdoublearray
    assert_equal(Java::double.java_class, ary.class.java_class.component_type)
    assert_equal(5, ary.size)
    assert_equal([0.0,0.0,0.0,0.0,0.0], ary.to_a)
  end

  def test_file_builder
    builder = JVMScript::FileBuilder.build("somefile.source") do
      package "org.awesome", "stuff" do
        public_class "MyClass", object do
          public_field "list", ArrayList

          public_constructor string, ArrayList do
            aload 0
            invokespecial object, "<init>", [void]
            aload 0
            aload 1
            aload 2
            invokevirtual this, "bar", [ArrayList, string, ArrayList]
            aload 0
            swap
            putfield this, "list", ArrayList
            returnvoid
          end

          public_static_method "foo", this, string do
            new this
            dup
            aload 0
            new ArrayList
            dup
            invokespecial ArrayList, "<init>", [void]
            invokespecial this, "<init>", [void, string, ArrayList]
            areturn
          end

          public_method "bar", ArrayList, string, ArrayList do
            aload 1
            invokevirtual(string, "toLowerCase", string)
            aload 2
            swap
            invokevirtual(ArrayList, "add", [boolean, object])
            aload 2
            areturn
          end

          public_method("getList", ArrayList) do
            aload 0
            getfield this, "list", ArrayList
            areturn
          end

          public_static_method("main", void, string[]) do
            aload 0
            ldc_int 0
            aaload
            invokestatic this, "foo", [this, string]
            invokevirtual this, "getList", ArrayList
            aprintln
            returnvoid
          end
        end
      end
    end

    # admittedly, this isn't much of a unit test, but it is what it is
    assert builder
  end
end
