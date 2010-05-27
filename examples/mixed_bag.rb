require 'java'
require 'jruby'
require 'bitescript'

import java.util.ArrayList

# Construct a class that uses several JVM opcodes and method types
builder = BiteScript::FileBuilder.build("somefile.source") do
  package "org.awesome", "stuff" do
    public_class "MyClass", object do
      public_field "list", ArrayList

      public_constructor [], string, ArrayList do
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

      public_static_method "foo", [], this, string do
        new this
        dup
        aload 0
        new ArrayList
        dup
        invokespecial ArrayList, "<init>", [void]
        invokespecial this, "<init>", [void, string, ArrayList]
        areturn
      end

      public_method "bar", [], ArrayList, string, ArrayList do
        aload 1
        invokevirtual(string, "toLowerCase", string)
        aload 2
        swap
        invokevirtual(ArrayList, "add", [boolean, object])
        aload 2
        areturn
      end

      public_method("getList", [], ArrayList) do
        aload 0
        getfield this, "list", ArrayList
        areturn
      end

      public_static_method("main", [], void, string[]) do
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

 # Load and instantiate using JRuby's class loader
loader = JRuby.runtime.jruby_class_loader
builder.generate do |name, builder|
  bytes = builder.generate
  cls = loader.define_class(name[0..-7].gsub('/', '.'), bytes.to_java_bytes)
  MyClass = JavaUtilities.get_proxy_class(cls.name)
  MyClass.main(['hello, BiteScript'].to_java :string)
end
