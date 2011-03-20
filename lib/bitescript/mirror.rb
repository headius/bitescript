require 'jruby'

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
    attr_accessor :superclass, :signature

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
      if name_or_bytes.kind_of?(String)
        classname = name_or_bytes.tr('.', '/') + ".class"
        stream = JRuby.runtime.jruby_class_loader.getResourceAsStream(
            classname)
        raise NameError, "Class '#{name_or_bytes}' not found." unless stream
        name_or_bytes = stream
      end
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

    def type_parameters
      signature.type_parameters is signature
    end

    def generic_superclass
      signature.superclass if signature
    end

    def generic_interfaces
      signature.interfaces if signature
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
        @class.signature = SignatureMirror.new(signature) if signature
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
        signature = GenericTypeBuilder.read(signature)
        @current = FieldMirror.new(@class.type, flags, name, Type.getType(desc), signature, value)
        @class.addField(@current)
        self
      end

      def visitMethod(flags, name, desc, signature, exceptions)
        return_type = Type.getReturnType(desc)
        parameters = Type.getArgumentTypes(desc).to_a
        exceptions = (exceptions || []).map {|e| Type.getObjectType(e)}
        signature = SignatureMirror.new(signature) if signature
        @current = MethodMirror.new(
            @class.type, flags, return_type, name, parameters, exceptions, signature)
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

    attr_reader :declaring_class, :name, :type, :value, :signature
    def initialize(klass, flags, name, type, signature, value)
      @declaring_class = klass
      @flags = flags
      @name = name
      @type = type
      @value = value
      @signature = signature
    end

    def generic_type
      signature
    end

    def inspect
      inspect_annotations + "#{modifier_string}#{type.getClassName} #{name};"
    end
  end

  class MethodMirror
    include Modifiers
    include Annotated

    attr_reader :declaring_class, :name, :return_type
    attr_reader :argument_types, :exception_types, :signature

    def initialize(klass, flags, return_type, name, parameters, exceptions, signature)
      @flags = flags
      @declaring_class = klass
      @name = name
      @return_type = return_type
      @argument_types = parameters
      @exception_types = exceptions
    end

    def generic_parameter_types
      signature.parameter_types if signature
    end

    def generic_return_type
      signature.return_type if signature
    end

    def generic_exception_types
      signature.exception_types if signature
    end

    def type_parameters
      signature.type_parameters is signature
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

  class SignatureMirror
    include BiteScript::ASM::SignatureVisitor

    attr_reader :type_parameters
    attr_reader :parameter_types, :return_type, :exception_types
    attr_reader :superclass, :interfaces

    def method?
      return_type != nil
    end

    def class?
      superclass != nil
    end

    def initialize(signature=nil)
      @type_parameters = []
      @parameter_types = []
      @exception_types = []
      @interfaces = []
      if (signature)
        reader = BiteScript::ASM::SignatureReader.new(signature)
        reader.accept(self)
      end
    end

    def visitFormalTypeParameter(name)
      type_parameters << TypeVariable.new(name)
    end

    def visitClassBound
      GenericTypeBuilder.new {|bound| type_parameters[-1].bounds << bound}
    end

    def visitInterfaceBound
      GenericTypeBuilder.new {|bound| type_parameters[-1].bounds << bound}
    end

    def visitParameterType
      GenericTypeBuilder.new {|type| parameter_types << type}
    end

    def visitReturnType
      GenericTypeBuilder.new {|type| @return_type = type}
    end

    def visitExceptionType
      GenericTypeBuilder.new {|type| exception_types << type}
    end

    def visitSuperclass
      GenericTypeBuilder.new {|type| @superclass = type}
    end

    def visitInterface
      GenericTypeBuilder.new {|type| interfaces << type}
    end
  end

  class GenericTypeMirror
    def array?
      false
    end
    def wildcard?
      false
    end
    def generic_class?
      false
    end
    def type_variable?
      false
    end
    def inspect
      "<#{self.class.name} #{to_s}>"
    end
  end

  class TypeVariable < GenericTypeMirror
    attr_reader :name, :bounds
    def initialize(name)
      @name = name
      @bounds = []
    end
    def type_variable?
      true
    end

    def to_s
      result = "#{name}"
      unless bounds.empty?
        result << ' extends ' << bounds.map {|b| b.to_s}.join(' & ')
      end
      result
    end
  end

  class GenericArray < GenericTypeMirror
    attr_accessor :component_type
    def array?
      true
    end
    def to_s
      "#{component_type}[]"
    end
  end

  class Wildcard < GenericTypeMirror
    attr_reader :lower_bound, :upper_bound
    def initialize(upper_bound, lower_bound=nil)
      @upper_bound = upper_bound
      @lower_bound = lower_bound
    end
    def wildcard?
      true
    end
    def to_s?
      if lower_bound
        "? super #{lower_bound}"
      elsif upper_bound
        "? extends #{upper_bound}"
      else
        "?"
      end
    end
  end

  class ParameterizedType < GenericTypeMirror
    attr_reader :raw_type, :type_arguments, :outer_type

    def initialize(raw_type, outer_type=nil)
      @raw_type = raw_type
      @type_arguments = []
      @outer_type = outer_type
    end

    def descriptor
      raw_type.descriptor
    end

    def generic_class?
      true
    end

    def to_s
      name = raw_type.internal_name.tr('/', '.')
      unless type_arguments.empty?
        name << "<#{type_arguments.map {|a| a.to_s}.join(', ')}>"
      end
      if outer_type
        "#{outer_type}.#{name}"
      else
        name
      end
    end
  end

  class GenericTypeBuilder
    include BiteScript::ASM::SignatureVisitor
    attr_reader :result

    def self.read(signature)
      if signature
        builder = GenericTypeBuilder.new
        reader = BiteScript::ASM::SignatureReader.new(signature)
        reader.accept(builder)
        builder.result
      end
    end

    def initialize(&block)
      @block = block
    end

    def return_type(type)
      @result = type
      @block.call(type) if @block
    end

    def visitBaseType(desc)
      return_type(Type.getType(desc.chr))
    end

    def visitArrayType
      type = GenericArray.new
      return_type(type)
      GenericTypeBuilder.new {|component_type| type.component_type = component_type}
    end

    def visitTypeVariable(name)
      return_type(TypeVariable.new(name))
    end

    def visitClassType(desc)
      return_type(ParameterizedType.new(Type.getObjectType(desc)))
    end

    def visitTypeArgument(wildcard=nil)
      if wildcard.nil?
        @result.type_arguments <<
            Wildcard.new(Type.getObjectType('java/lang/Object'))
        return
      end
      GenericTypeBuilder.new do |type|
        argument = case wildcard
        when INSTANCEOF
          type
        when EXTENDS
          Wildcard.new(type)
        when SUPER
          Wildcard.new(nil, type)
        else
          raise "Unknown wildcard #{wildcard.chr}"
        end
        @result.type_arguments << argument
      end
    end

    def visitSuperclass
      self
    end

    def visitInnerClassType(name)
      desc = @result.descriptor.sub(/;$/, "$#{name};")
      return_type(ParameterizedType.new(Type.getType(desc), @result))
    end

    def visitEnd
      if @result.type_arguments.empty? && @result.outer_type.nil?
        @result = @result.raw_type
      end
    end
  end
end