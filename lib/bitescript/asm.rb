require 'java'

module BiteScript
  module ASM
    begin
      # try mangled names for the version included with JRuby
      java.lang.Class.for_name 'jruby.objectweb.asm.Opcodes'
      
      # no error, proceed with mangled name
      asm_package = Java::jruby.objectweb.asm
      java_import asm_package.Opcodes
    rescue Exception
      # fall back on standard names
      asm_package = org.objectweb.asm
      java_import asm_package.Opcodes
    end
    java_import asm_package.Label
    java_import asm_package.Type
    java_import asm_package.ClassWriter
    java_import asm_package.util.CheckClassAdapter
  end
end
