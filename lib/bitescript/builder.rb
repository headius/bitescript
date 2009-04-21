require 'bitescript/bytecode'
require 'bitescript/signature'
require 'fileutils'

module BiteScript
  module Util
    def type_from_dotted(dotted_name)
      JavaUtilities.get_proxy_class(dotted_name).java_class
    end
  end

  module QuickTypes
    def void
      Java::void
    end

    def boolean
      Java::boolean
    end

    def byte
      Java::byte
    end

    def short
      Java::short
    end

    def char
      Java::char
    end

    def int
      Java::int
    end

    def long
      Java::long
    end

    def float
      Java::float
    end

    def double
      Java::double
    end

    def object
      Java::java.lang.Object
    end

    def string
      Java::java.lang.String
    end

    def null
      nil
    end
  end
  
  class FileBuilder
    include Util
    include QuickTypes
    
    attr_accessor :file_name
    attr_accessor :class_builders
    attr_accessor :imports
    attr_accessor :package
    
    def initialize(file_name)
      @file_name = file_name
      @class_builders = {}
      @imports = {}
      @package = []
      
      init_imports
    end
    
    def init_imports
      # set up a few useful imports
      @imports[:int.to_s] = Java::int.java_class
      @imports[:string.to_s] = Java::java.lang.String.java_class
      @imports[:object.to_s] = Java::java.lang.Object.java_class
    end

    def self.build(filename, &block)
      fb = new(filename)
      if block_given?
        fb.instance_eval(&block)
      end
      fb
    end

    def define_class(class_name, opts, &block)
      pkg = opts[:package] || @package || []
      class_name = pkg.empty? ? class_name : "#{pkg.join('/')}/#{class_name}"
      class_builder = ClassBuilder.new(self, class_name, @file_name, opts)
      @class_builders[class_name] ||= class_builder # TODO Is this really what we want?
      
      if block_given?
        if block.arity == 1
          block.call(class_builder)
        else
          class_builder.instance_eval(&block)
        end
      else
        return class_builder
      end
    end
    
    def public_class(class_name, superclass = java.lang.Object, *interfaces, &block)
      define_class(class_name, :visibility => :public, :superclass => superclass, :interfaces => interfaces, &block)
    end
    
    def protected_class(class_name, superclass = java.lang.Object, *interfaces, &block)
      define_class(class_name, :visibility => :protected, :superclass => superclass, :interfaces => interfaces, &block)
    end
    
    def private_class(class_name, superclass = java.lang.Object, *interfaces, &block)
      define_class(class_name, :visibility => :private, :superclass => superclass, :interfaces => interfaces, &block)
    end
    
    def default_class(class_name, superclass = java.lang.Object, *interfaces, &block)
      define_class(class_name, :visibility => :default, :superclass => superclass, :interfaces => interfaces, &block)
    end
    
    def generate
      @class_builders.each do |class_name, class_builder|
        class_file = "#{class_name.gsub('.', '/')}.class"
        
        yield class_file, class_builder
      end
    end
    
    def line(line)
      # No tracking of lines at the file level, so we ignore
    end
    
    def package(*names)
      elements = 0
      names.each do |name_maybe_dotted|
        name_maybe_dotted.split(/\./).each do |name|
          elements += 1
          @package.push name
        end
      end
      yield
      elements.times {@package.pop}
    end
    
    def method?
      false
    end
  end
  
  class ClassBuilder
    include Util
    include QuickTypes

    begin
      import "jruby.objectweb.asm.Opcodes"
      import "jruby.objectweb.asm.ClassWriter"
    rescue
      import "org.objectweb.asm.Opcodes"
      import "org.objectweb.asm.ClassWriter"
    end
    
    import java.lang.Object
    import java.lang.Void
    include Signature
    
    attr_accessor :class_name
    attr_accessor :superclass
    attr_accessor :constructors
    attr_accessor :methods
    attr_accessor :imports
    attr_accessor :fields

    def initialize(file_builder, class_name, file_name, opts) 
      @parent = file_builder
      @class_name = class_name
      @superclass = opts[:superclass] || Object
      
      @class_writer = ClassWriter.new(ClassWriter::COMPUTE_MAXS)
      
      interface_paths = []
      (opts[:interfaces] || []).each {|interface| interface_paths << path(interface)}

      visibility = case (opts[:visibility] && opts[:visibility].to_sym)
        when nil
          Opcodes::ACC_PUBLIC  # NOTE Not specified means public -- must explicitly ask for default
        when :default
          0
        when :public
          Opcodes::ACC_PUBLIC
        when :private
          Opcodes::ACC_PRIVATE
        when :protected
          Opcodes::ACC_PROTECTED
        else
          raise "Unknown visibility: #{opts[:visibility]}"
      end

      @class_writer.visit(BiteScript.bytecode_version, visibility | Opcodes::ACC_SUPER, class_name, nil, path(superclass), interface_paths.to_java(:string))
      @class_writer.visit_source(file_name, nil)

      @constructor = nil
      @constructors = {}
      @methods = {}
      
      @imports = {}
      
      @fields = {}
    end

    def start
    end

    def stop
      # if we haven't seen a constructor, generate a default one
      unless @constructor
        method = MethodBuilder.new(self, Opcodes::ACC_PUBLIC, "<init>", [])
        method.start
        method.aload 0
        method.invokespecial @superclass, "<init>", Void::TYPE
        method.returnvoid
        method.stop
      end
    end
    
    def generate
      String.from_java_bytes(@class_writer.to_byte_array)
    end

    %w[public private protected].each do |modifier|
      # instance fields
      eval "
        def #{modifier}_field(name, type)
          field(Opcodes::ACC_#{modifier.upcase}, name, type)
        end
      ", binding, __FILE__, __LINE__
      # static fields
      eval "
        def #{modifier}_static_field(name, type)
          field(Opcodes::ACC_STATIC | Opcodes::ACC_#{modifier.upcase}, name, type)
        end
      ", binding, __FILE__, __LINE__
      # instance methods; also defines a "this" local at index 0
      eval "
        def #{modifier}_method(name, *signature, &block)
          method(Opcodes::ACC_#{modifier.upcase}, name, signature, &block)
        end
      ", binding, __FILE__, __LINE__
      # static methods
      eval "
        def #{modifier}_static_method(name, *signature, &block)
          method(Opcodes::ACC_STATIC | Opcodes::ACC_#{modifier.upcase}, name, signature, &block)
        end
      ", binding, __FILE__, __LINE__
      # native methods
      eval "
        def #{modifier}_native_method(name, *signature)
          method(Opcodes::ACC_NATIVE | Opcodes::ACC_#{modifier.upcase}, name, signature)
        end
      ", binding, __FILE__, __LINE__
      # constructors; also defines a "this" local at index 0
      eval "
        def #{modifier}_constructor(*signature, &block)
          method(Opcodes::ACC_#{modifier.upcase}, \"<init>\", [nil, *signature], &block)
        end
      ", binding, __FILE__, __LINE__
    end

    def static_init(&block)
      method(Opcodes::ACC_STATIC, "<clinit>", [void], &block)
    end
    
    def method(flags, name, signature, &block)
      mb = MethodBuilder.new(self, flags, name, signature)

      if name == "<init>"
        constructors[signature[1..-1]] = mb
      else
        methods[name] ||= {}
        methods[name][signature[1..-1]] = mb
      end

      # non-static methods reserve index 0 for 'this'
      mb.local 'this' if (flags & Opcodes::ACC_STATIC) == 0
      
      if block_given?
        mb.start
        if block.arity == 1
          block.call(mb)
        else
          mb.instance_eval(&block)
        end
        mb.stop
      end

      mb
    end

    def java_method(name, *params)
      if methods[name]
        method = methods[name][params]
      end

      method or raise NameError.new("failed to find method #{name}#{sig(params)} on #{self}")
    end

    def main(&b)
      raise "already defined main" if methods[name]

      public_static_method "main", void, string[], &b
    end

    def constructor(*params)
      constructors[params] or raise NameError.new("failed to find constructor #{sig(params)} on #{self}")
    end

    def interface?
      # TODO: interface types
      false
    end
    
    def field(flags, name, type)
      @class_writer.visit_field(flags, name, ci(type), nil, nil)
    end
    
    # name for signature generation using the class being generated
    def name
      @class_name
    end
    
    # never generating an array
    def array?
      false
    end
    
    # never generating a primitive
    def primitive?
      false
    end
    
    def this
      self
    end
    
    def new_method(modifiers, name, signature)
      @class_writer.visit_method(modifiers, name, sig(*signature), nil, nil)
    end

    def macro(name, &b)
      MethodBuilder.send :define_method, name, &b
    end
  end
  
  class MethodBuilder
    begin
      import "jruby.objectweb.asm.Opcodes"
    rescue
      import "org.objectweb.asm.Opcodes"
    end

    include QuickTypes
    include BiteScript::Bytecode
    
    attr_reader :method_visitor
    attr_reader :static
    attr_reader :signature
    attr_reader :name
    attr_reader :class_builder
    
    def initialize(class_builder, modifiers, name, signature)
      @class_builder = class_builder
      @modifiers = modifiers
      @name = name
      @signature = signature
      
      @method_visitor = class_builder.new_method(modifiers, name, signature)
      
      @locals = {}
      
      @static = (modifiers & Opcodes::ACC_STATIC) != 0
    end

    def parameter_types
      signature[1..-1]
    end

    def return_type
      signature[0]
    end

    def declaring_class
      @class_builder
    end
    
    def self.build(class_builder, modifiers, name, signature, &block)
      mb = MethodBuilder.new(class_builder, modifiers, name, signature)
      mb.start
      if block.arity == 1
        block.call(mb)
      else
        mb.instance_eval(&block)
      end
      mb.stop
    end
    
    def self.build2(class_builder, modifiers, name, signature, &block)
      mb = MethodBuilder.new(class_builder, modifiers, name, signature)
      mb.start
      block.call(mb)
      mb.stop
    end
    
    def generate(&block)
      start
      block.call(self)
      stop
    end
    
    def this
      @class_builder
    end
    
    def local(name)
      if name == "this" && @static
        raise "'this' attempted to load from static method"
      end
      
      if @locals[name]
        local_index = @locals[name]
      else
        local_index = @locals[name] = @locals.size
      end
      local_index
    end

    def annotate(cls, runtime = false)
      if Java::JavaClass == cls
        java_class = cls
      else
        java_class = cls.java_class
      end

      annotation = @method_visitor.visit_annotation(ci(java_class), true)
      annotation.extend AnnotationBuilder

      yield annotation
      annotation.visit_end
    end
  end

  module AnnotationBuilder
    def method_missing(name, val)
      name_str = name.to_s
      if name_str[-1] == ?=
        name_str = name_str[0..-2]
        if Array === val
          array(name_str) do |ary|
            val.each {|x| ary.visit(nil, x)}
          end
        else
          visit name_str, val
        end
      else
        super
      end
    end
    def value(k, v)
      visit k, v
    end
    def annotation(name, cls)
      if Java::JavaClass == cls
        java_class = cls
      else
        java_class = cls.java_class
      end

      sub_annotation = visit_annotation(name, ci(java_class))
      sub_annotation.extend AnnotationBuilder
      yield sub_annotation
      sub_annotation.visit_end
    end
    def array(name)
      sub_annotation = visit_array(name)
      sub_annotation.extend AnnotationBuilder
      yield sub_annotation
      sub_annotation.visit_end
    end
    def enum(name, cls, value)
      if JavaClass == cls
        java_class = cls
      else
        java_class = cls.java_class
      end

      visit_enum(name, ci(java_class), value)
    end
  end
end
