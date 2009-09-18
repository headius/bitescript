require 'bitescript/asm'
require 'bitescript/signature'

module BiteScript
  # Bytecode is a simple adapter around an ASM MethodVisitor that makes it look like
  # JVM assembly code. Included classes must just provide a method_visitor accessor
  module Bytecode
    include Signature
    include ASM

    JObject = java.lang.Object
    JSystem = java.lang.System
    JPrintStream = java.io.PrintStream
    JVoid = java.lang.Void
    JInteger = java.lang.Integer
    JFloat = java.lang.Float
    JLong = java.lang.Long
    JDobule = java.lang.Double
    
    b = binding
    OpcodeStackDeltas = {}
    %w[ALOAD ILOAD FLOAD BIPUSH SIPUSH DUP DUP_X1 DUP_X2 ACONST_NULL ICONST_M1
       ICONST_0 ICONST_1 ICONST_2 ICONST_3 ICONST_4 ICONST_5 I2L I2D FCONST_0
       FCONST_1 FCONST_2 F2L F2D NEW JSR].each {|opcode| OpcodeStackDeltas[opcode] = 1}
    %w[LLOAD DLOAD DUP2 DUP2_X1 DUP2_X2 LCONST_0 LCONST_1 DCONST_0 DCONST_1].each {|opcode| OpcodeStackDeltas[opcode] = 2}
    %w[ASTORE ISTORE FSTORE POP ARETURN IRETURN ATHROW AALOAD BALOAD CALOAD
       SALOAD IALOAD FALOAD IADD ISUB IDIV IMUL IAND IOR IXOR IREM L2I L2F
       FRETURN FADD FSUB FDIV FMUL FREM FCMPG FCMPL D2I D2F IFEQ IFNE IFNULL
       IFNONNULL IFLT IFGT IFLE IFGE LOOKUPSWITCH TABLESWITCH MONITORENTER
       MONITOREXIT].each {|opcode| OpcodeStackDeltas[opcode] = -1}
    %w[LSTORE DSTORE POP2 LREM LADD LSUB LDIV LMUL LAND LOR LXOR LRETURN DRETURN
       DADD DSUB DDIV DMUL DREM IF_ACMPEQ IF_ACMPNE IF_ICMPEQ IF_ICMPNE
       IF_ICMPLT IF_ICMPGT IF_ICMPLE IF_ICMPGE].each {|opcode| OpcodeStackDeltas[opcode] = -2}
    %w[AASTORE BASTORE CASTORE SASTORE IASTORE LCMP FASTORE DCMPL DCMPG].each {|opcode| OpcodeStackDeltas[opcode] = -3}
    %w[LASTORE DASTORE].each {|opcode| OpcodeStackDeltas[opcode] = -4}
    %w[RETURN SWAP NOP ARRAYLENGTH IINC INEG IUSHR ISHL ISHR I2S I2F I2B I2C
       LALOAD LSHL LSHR LUSHR LNEG L2D FNEG F2I DALOAD D2L DNEG RET
       CHECKCAST ANEWARRAY NEWARRAY GOTO INSTANCEOF].each {|opcode| OpcodeStackDeltas[opcode] = 0}
    
    OpcodeInstructions = {}

    Opcodes.constants.each do |const_name|
      const_down = const_name.downcase
      
      case const_name
      when "ALOAD", "ASTORE",
          "ISTORE", "ILOAD",
          "LSTORE", "LLOAD",
          "FSTORE", "FLOAD",
          "DSTORE", "DLOAD",
          "RET"
        # variable instructions
        line = __LINE__; eval "
            def #{const_down}(var)
              method_visitor.visit_var_insn(Opcodes::#{const_name}, var)
              #{OpcodeStackDeltas[const_name]}
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down
          
      when "LDC"
        # constant loading is tricky because overloaded invocation is pretty bad in JRuby
        def ldc_int(value); method_visitor.visit_ldc_insn(java.lang.Integer.new(value)); 1; end
        def ldc_long(value); method_visitor.visit_ldc_insn(java.lang.Long.new(value)); 2; end
        def ldc_float(value); method_visitor.visit_ldc_insn(java.lang.Float.new(value)); 1; end
        def ldc_double(value); method_visitor.visit_ldc_insn(java.lang.Double.new(value)); 2; end
        def ldc_class(value)
          value = value.java_class unless Java::JavaClass === value
          method_visitor.visit_ldc_insn(ASM::Type.get_type(value))
          1
        end
        line = __LINE__; eval "
            def #{const_down}(value)
              size = 1

              case value
              when Symbol
                method_visitor.visit_ldc_insn value.to_s
              when Fixnum
                size = push_int value
              when Float
                ldc_double(value)
              when Module
                ldc_class(value)
              else
                method_visitor.visit_ldc_insn(value)
              end

              size
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down

      when "BIPUSH", "SIPUSH"
        line = __LINE__; eval "
            def #{const_down}(value)
              method_visitor.visit_int_insn(Opcodes::#{const_name}, value)
              1
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down
          
      when "INVOKESTATIC", "INVOKEVIRTUAL", "INVOKEINTERFACE", "INVOKESPECIAL", "INVOKEDYNAMIC"
        # method instructions
        line = __LINE__; eval "
            def #{const_down}(type, name, call_sig)
              method_visitor.visit_method_insn(Opcodes::#{const_name}, path(type), name.to_s, sig(*call_sig))

              case call_sig[0]
              when nil, Java::void, java.lang.Void
                added = 0
              when Java::boolean, Java::short, Java::char, Java::int, Java::float
                added = 1
              when Java::long, Java::double
                added = 2
              else
                added = 1
              end

              this_subtracted = #{const_name == 'INVOKESTATIC' ? 0 : 1}

              args_subtracted = 0
              [*call_sig][1..-1].each do |param|
                case param
                when nil, Java::void, java.lang.Void
                  args_subtracted += 0
                when Java::boolean, Java::short, Java::char, Java::int, Java::float
                  args_subtracted += 1
                when Java::long, Java::double
                  args_subtracted += 2
                else
                  args_subtracted += 1
                end
              end

              added - (this_subtracted + args_subtracted)
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down
          
      when "RETURN"
        # special case for void return, since return is a reserved word
        def returnvoid()
          method_visitor.visit_insn(Opcodes::RETURN)
          0
        end
        OpcodeInstructions['RETURN'] = 'returnvoid'
        
      when "DUP", "SWAP", "POP", "POP2", "DUP_X1", "DUP_X2", "DUP2", "DUP2_X1", "DUP2_X2",
          "NOP",
          "ARRAYLENGTH",
          "ARETURN", "ATHROW", "ACONST_NULL", "AALOAD", "AASTORE",
          "BALOAD", "BASTORE",
          "CALOAD", "CASTORE",
          "SALOAD", "SASTORE",
          "ICONST_M1", "ICONST_0", "ICONST_1", "ICONST_2", "ICONST_3", "ICONST_4", "ICONST_5", "IRETURN", "IALOAD",
          "IADD", "ISUB", "IDIV", "IMUL", "INEG", "IAND", "IOR", "IXOR", "IASTORE",
          "IUSHR", "ISHL", "ISHR", "I2L", "I2S", "I2F", "I2D", "I2B", "IREM", "I2C",
          "LCONST_0", "LCONST_1", "LRETURN", "LALOAD", "LASTORE", "LCMP", "LSHL", "LSHR", "LREM", "LUSHR",
          "LADD", "LINC", "LSUB", "LDIV", "LMUL", "LNEG", "LAND", "LOR", "LXOR", "L2I", "L2F", "L2D",
          "FCONST_0", "FCONST_1", "FCONST_2", "FRETURN", "FALOAD", "F2D", "F2I", "FASTORE",
          "FADD", "FSUB", "FDIV", "FMUL", "FNEG", "FREM", "FCMPG", "F2L", "FCMPL",
          "DCONST_0", "DCONST_1", "DRETURN", "DALOAD", "DASTORE", "D2I", "D2F", "D2L",
          "DADD", "DINC", "DSUB", "DDIV", "DMUL", "DNEG", "DCMPL", "DCMPG", "DREM",
          "MONITORENTER", "MONITOREXIT"
        # bare instructions
        line = __LINE__; eval "
            def #{const_down}
              method_visitor.visit_insn(Opcodes::#{const_name})
              #{OpcodeStackDeltas[const_name]}
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down

      when "IINC"
        def iinc(index, value)
          method_visitor.visit_iinc_insn(index, value)
          0
        end
        OpcodeInstructions[const_name] = 'iinc'
          
      when "NEW", "ANEWARRAY", "INSTANCEOF", "CHECKCAST"
        # type instructions
        line = __LINE__; eval "
            def #{const_down}(type)
              method_visitor.visit_type_insn(Opcodes::#{const_name}, path(type))
              #{OpcodeStackDeltas[const_name]}
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down

      when "NEWARRAY"
        # newaray has its own peculiarities
       NEWARRAY_TYPES = {
          :boolean => Opcodes::T_BOOLEAN,
          :byte => Opcodes::T_BYTE,
          :short => Opcodes::T_SHORT,
          :char => Opcodes::T_CHAR,
          :int => Opcodes::T_INT,
          :long => Opcodes::T_LONG,
          :float => Opcodes::T_FLOAT,
          :double => Opcodes::T_DOUBLE
        }
        NEWARRAY_TYPES.each do |type, op_type|
          line = __LINE__; eval "
              def new#{type}array()
                method_visitor.visit_int_insn(Opcodes::#{const_name}, #{op_type})
                #{OpcodeStackDeltas[const_name]}
              end
            ", b, __FILE__, line
        end
        def newarray(type)
          t_type = NEWARRAY_TYPES[path(type).intern]
          method_visitor.visit_int_insn(Opcodes::NEWARRAY, t_type)
        end
        OpcodeInstructions[const_name] = const_down
          
      when "GETFIELD", "PUTFIELD", "GETSTATIC", "PUTSTATIC"
        # field instructions
        line = __LINE__; eval "
            def #{const_down}(type, name, field_type)
              method_visitor.visit_field_insn(Opcodes::#{const_name}, path(type), name.to_s, ci(field_type))

              case field_type
              when Java::boolean, Java::short, Java::char, Java::int, Java::float
                delta = 1
              when Java::long, Java::double
                delta = 2
              else
                delta = 1
              end

              this_subtracted = #{const_name[3..7] == 'STATI' ? 0 : 1}

              delta *= #{const_name[0..2] == 'PUT' ? -1 : 1}
              delta -= this_subtracted
              delta
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down
          
      when "GOTO", "IFEQ", "IFNE", "IF_ACMPEQ", "IF_ACMPNE", "IF_ICMPEQ", "IF_ICMPNE", "IF_ICMPLT",
          "IF_ICMPGT", "IF_ICMPLE", "IF_ICMPGE", "IFNULL", "IFNONNULL", "JSR",
          "IFLE", "IFGE", "IFLT", "IFGT"
        # jump instructions
        line = __LINE__; eval "
            def #{const_down}(target)
              target = sym_to_label(target) if Symbol === target
              method_visitor.visit_jump_insn(Opcodes::#{const_name}, target.label)
              #{OpcodeStackDeltas[const_name]}
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down
          
      when "MULTIANEWARRAY"
        # multi-dim array
        line = __LINE__; eval "
            def #{const_down}(type, dims)
              method_visitor.visit_multi_anew_array_insn(ci(type), dims)
              -dims
            end
          ", b, __FILE__, line
        OpcodeInstructions[const_name] = const_down
          
      when "LOOKUPSWITCH"
        def lookupswitch(default, ints, cases = [])
          cases = cases.to_ary
          if cases.size > 0
            # symbol labels, map them to actual
            case_labels = cases.map do |lbl|
              lbl = sym_to_label(lbl) if Symbol === lbl
              lbl.label
            end
          end
          raise "Default case must be provided" unless default
          if default && Symbol === default
            default = sym_to_label(default)
          end
          method_visitor.visit_lookup_switch_insn(default.label, ints.to_java(:int), case_labels.to_java(ASM::Label))
          -1
        end
        OpcodeInstructions['LOOKUPSWITCH'] = 'lookupswitch'
        
      when "TABLESWITCH"
        def tableswitch(min, max, default, cases = [])
          cases = cases.to_ary
          if cases.size > 0
            # symbol labels, map them to actual
            case_labels = cases.map do |lbl|
              lbl = sym_to_label(lbl) if Symbol === lbl
              lbl.label
            end
          end
          raise "Default case must be provided" unless default
          if default && Symbol === default
            default = sym_to_label(default)
          end
          method_visitor.visit_table_switch_insn(min, max, default.label, case_labels.to_java(ASM::Label))
          -1
        end
        OpcodeInstructions['TABLESWITCH'] = 'tableswitch'

      when "F_FULL", "ACC_ENUM", "ACC_SYNTHETIC", "ACC_INTERFACE", "ACC_PUBLIC",
          "ACC_PRIVATE", "ACC_PROTECTED", "ACC_DEPRECATED", "ACC_BRIDGE",
          "ACC_VARARGS", "ACC_SUPER", "F_CHOP", "F_APPEND", "FLOAT", "F_SAME",
          "T_LONG", "INTEGER", "T_BYTE", "ACC_STATIC", "ACC_SYNCHRONIZED",
          "T_BOOLEAN", "ACC_ANNOTATION", "ACC_ABSTRACT", "LONG", "ACC_TRANSIENT",
          "T_DOUBLE", "DOUBLE", "ACC_STRICT", "NULL", "T_FLOAT", "ACC_FINAL",
          "F_SAME1", "ACC_NATIVE", "F_NEW", "T_CHAR", "T_INT", "ACC_VOLATILE",
          "V1_6", "V1_5", "V1_4", "V1_3", "V1_2", "V1_1", "UNINITIALIZED_THIS",
          "TOP", "T_SHORT", "INVOKEDYNAMIC_OWNER", "V1_7"
        # non-instructions

      else
        raise "Unknown opcode: " + const_name
        
      end
    end
    
    def start
      method_visitor.visit_code
      @start_label.set!
    end
    
    def stop
      @end_label.set!
      @locals.each do |name, (local_index, type)|
        method_visitor.visit_local_variable(name, type, nil,
                                            @start_label.label,
                                            @end_label.label,
                                            local_index)
      end
      method_visitor.visit_maxs(1,1)
      method_visitor.visit_end
    end
    
    def trycatch(from, to, target, type)
      from = sym_to_label(from) if Symbol === from
      to = sym_to_label(to) if Symbol === to
      target = sym_to_label(target) if Symbol === target
      
      method_visitor.visit_try_catch_block(from.label, to.label, target.label, type ? path(type) : nil)
    end
    
    class SmartLabel
      attr_reader :label
      
      def initialize(method_visitor)
        @method_visitor = method_visitor
        @label = ASM::Label.new
      end
      
      def set!
        @method_visitor.visit_label(@label)
        self
      end
    end

    def labels
      @labels ||= {}
    end

    def sym_to_label(id)
      lbl = labels[id] or raise "Unknown label '#{id}'"
    end
    
    def label(id = nil)
      if id
        label = labels[id]
        if label
          raise "Duplicate label '#{id}'"
        end
        label = labels[id] = SmartLabel.new(method_visitor)
        label.set!
        label
      else
        return SmartLabel.new(method_visitor)
      end
    end
    
    def aprintln
      println
    end
    
    def println(type = JObject)
      getstatic JSystem, "out", JPrintStream
      swap
      invokevirtual JPrintStream, "println", [JVoid::TYPE, type]
    end
    
    def swap2
      dup2_x2
      pop2
    end
    
    def line(num)
      if num && num != @line_num
        method_visitor.visit_line_number(num, label.set!.label)
      end
      @line_num = num
    end

    def push_int(num)
      if (num <= Java::java.lang.Byte::MAX_VALUE && num >= Java::java.lang.Byte::MIN_VALUE)
        case num
        when -1
          iconst_m1
        when 0
          iconst_0
        when 1
          iconst_1
        when 2
          iconst_2
        when 3
          iconst_3
        when 4
          iconst_4
        when 5
          iconst_5
        else
          bipush(num)
        end
      elsif (num <= Java::java.lang.Short::MAX_VALUE && num >= Java::java.lang.Short::MIN_VALUE)
        sipush(num)
      elsif (num <= Java::java.lang.Integer::MAX_VALUE && num >= Java::java.lang.Integer::MIN_VALUE)
        ldc_int(num)
      else
        ldc_long(num)
      end
    end
  end
end
