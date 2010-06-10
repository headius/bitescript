module BiteScript::ASM
  class EnumValue
    attr_reader :declaring_type, :name

    def initialize(declaring_type, name)
      @declaring_type = declaring_type
      @name = name
    end
  end

  class AnnotationMirror
    attr_reader :type, :parent
    def initialize(type, parent=nil)
      @type = type
      @parent = parent
      @values = {}
    end

    def value
      @values['value']
    end

    def value=(value)
      @values['value'] = value
    end

    def [](name)
      @values[name]
    end

    def []=(name, value)
      @values[name] = value
    end

    def inspect
      unless @values.empty?
        values = []
        @values.each do |k, v|
          values << "#{k}=#{inspect_value(v)}"
        end
        values = "(#{values.join ', '})"
      end
      "@#{type.class_name}#{values}\n"
    end

    def inspect_value(v)
      case v
      when Type
        v.class_name + ".class"
      when Array
        "{#{v.map{|x| inspect_value(x)}.join(', ')}}"
      when EnumValue
        "#{v.declaring_type.class_name}.#{v.name}"
      else
        v.inspect
      end
    end

    class Builder
      class ValueArray
        attr_reader :parent
        def initialize(annotation, array)
          @parent = annotation
          @array = array
        end

        def []=(name, value)
          @array << value
        end
      end

      include BiteScript::ASM::AnnotationVisitor

      attr_reader :annotation
      def initialize(desc, visible)
        @current = @annotation = AnnotationMirror.new(Type.getType(desc))
      end


      def visit(name, value)
        case value
        when ArrayJavaProxy
          visitArray(name)
          value.each {|x| visit(name, x)}
          visitEnd
        else
          @current[name] = value
        end
      end

      def visitAnnotation(name, desc)
        child = AnnotationMirror.new(Type.getType(desc), @current)
        @current[name] = child
        @current = child
        self
      end

      def visitArray(name)
        array = @current[name] = []
        @current = ValueArray.new(@current, array)
        self
      end

      def visitEnum(name, desc, value)
        @current[name] = EnumValue.new(Type.getType(desc), value)
      end

      def visitEnd
        @current = @current.parent
      end
    end
  end

  module Annotated
    def annotations
      @annotations ||= {}
    end

    def addAnnotation(annotation)
      annotations[annotation.type.class_name] = annotation
    end

    def getDeclaredAnnotation(name)
      annotations[name]
    end

    def declaredAnnotations
      annotations.values
    end

    def inspect_annotations
      declaredAnnotations.map {|a| a.inspect}.join('')
    end
  end

  module Modifiers
    attr_accessor :flags
    def self.add_modifier(name)
      class_eval <<-EOF
        def #{name.downcase}?
          (flags & Opcodes.ACC_#{name.upcase}) != 0
        end
      EOF
    end
    %w(annotation bridge deprecated enum interface synthetic).each do |name|
      add_modifier(name)
    end
    code = ''
    %w(Public Private Protected Final Native Abstract
       Static Strict Synchronized Transient Volatile).each do |name|
      add_modifier(name)
      code << "modifiers << '#{name.downcase} ' if #{name.downcase}?\n"
    end

    class_eval <<-EOF
      def modifier_string
        modifiers = ''
        #{code}
        modifiers
      end
    EOF
  end

  class ClassMirror
    include Annotated
    include Modifiers

    attr_reader :type, :interfaces
    attr_accessor :superclass

    def initialize(type, flags)
      super()
      @type = type
      @flags = flags
      @methods = Hash.new {|h, k| h[k] = {}}
      @constructors = {}
      @fields = {}
      @interfaces = []
    end

    def self.load(name_or_bytes)
      builder = BiteScript::ASM::ClassMirror::Builder.new
      BiteScript::ASM::ClassReader.new(name_or_bytes).accept(builder, 3)
      builder.mirror
    end

    def self.for_name(name)
      load(name)
    end

    def getConstructor(*arg_types)
      @constructors[arg_types]
    end

    def getConstructors
      @constructors.values
    end

    def addConstructor(constructor)
      @constructors[constructor.parameters] = constructor
    end

    def getDeclaredMethod(name, *args)
      if args[0].kind_of?(Array)
        args = args[0]
      end
      @methods[name][args]
    end

    def getDeclaredMethods(name=nil)
      if name
        @methods[name].values
      else
        @methods.values.map {|m| m.values}.flatten
      end
    end

    def addMethod(method)
      # TODO this is a hack to fix resolution of covariant returns.
      # We should properly support methods that only differ by return type.
      return if method.synthetic?
      type_names = method.argument_types.map {|type| type.descriptor}
      if method.name == '<init>'
        @constructors[type_names] = method
      else
        @methods[method.name][type_names] = method
      end
    end

    def getField(name)
      @fields[name]
    end

    def getDeclaredFields
      @fields.values
    end

    def addField(field)
      @fields[field.name] = field
    end

    def inspect
      if annotation?
        kind = "@interface"
      elsif interface?
        kind = "interface"
      elsif enum?
        kind = "enum"
      else
        kind = "class"
      end
      if superclass && !enum? && !interface?
        extends = "extends #{superclass.getClassName} "
      end
      if self.interfaces && !self.interfaces.empty?
        interfaces = self.interfaces.map{|i| i.class_name}.join(', ')
        if interface?
          extends = "extends #{interfaces} "
        else
          implements = "implements #{interfaces} "
        end
      end
      result = "#{inspect_annotations}#{modifier_string}#{kind} "
      result << "#{type.class_name} #{extends}{\n"
      (getDeclaredFields + getConstructors + getDeclaredMethods).each do |f|
        result << f.inspect << "\n"
      end
      result << "}"
    end

    class Builder
      include BiteScript::ASM::ClassVisitor
      include BiteScript::ASM::FieldVisitor
      include BiteScript::ASM::MethodVisitor

      def visit(version, access, name, signature, super_name, interfaces)
        @current = @class = ClassMirror.new(Type.getObjectType(name), access)
        @class.superclass = Type.getObjectType(super_name) if super_name
        if interfaces
          interfaces.each do |i|
            @class.interfaces << Type.getObjectType(i)
          end
        end
      end

      def mirror
        @class
      end

      def visitSource(source, debug); end
      def visitOuterClass(owner, name, desc); end
      def visitAttribute(attribute); end
      def visitInnerClass(name, outer, inner, access); end
      def visitEnd; end

      def visitAnnotation(desc, visible)
        builder = AnnotationMirror::Builder.new(desc, visible)
        @current.addAnnotation(builder.annotation)
        builder
      end

      def visitField(flags, name, desc, signature, value)
        @current = FieldMirror.new(@class.type, flags, name, Type.getType(desc), value)
        @class.addField(@current)
        self
      end

      def visitMethod(flags, name, desc, signature, exceptions)
        return_type = Type.getReturnType(desc)
        parameters = Type.getArgumentTypes(desc).to_a
        exceptions = (exceptions || []).map {|e| Type.getObjectType(e)}
        @current = MethodMirror.new(
            @class.type, flags, return_type, name, parameters, exceptions)
        @class.addMethod(@current)
        # TODO parameter annotations, default value, etc.
        self  # This isn't legal is it?
      end

      def visitAnnotationDefault(*args);end

      def to_s
        "ClassMirror(#{type.class_name})"
      end
    end
  end

  class FieldMirror
    include Modifiers
    include Annotated

    attr_reader :declaring_class, :name, :type, :value
    def initialize(klass, flags, name, type, value)
      @declaring_class = klass
      @flags = flags
      @name = name
      @type = type
      @value = value
    end

    def inspect
      inspect_annotations + "#{modifier_string}#{type.getClassName} #{name};"
    end
  end

  class MethodMirror
    include Modifiers
    include Annotated

    attr_reader :declaring_class, :name, :return_type
    attr_reader :argument_types, :exception_types
    def initialize(klass, flags, return_type, name, parameters, exceptions)
      @flags = flags
      @declaring_class = klass
      @name = name
      @return_type = return_type
      @argument_types = parameters
      @exception_types = exceptions
    end

    def inspect
      "%s%s%s %s(%s);" % [
        inspect_annotations,
        modifier_string,
        return_type.class_name,
        name,
        argument_types.map {|x| x.class_name}.join(', '),
      ]
    end
  end
end