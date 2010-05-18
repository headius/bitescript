require 'java'

module BiteScript
  module ASM
    begin
      # try mangled names for the version included with JRuby
      asm_package = Java::jruby.objectweb.asm
      java_import asm_package.Opcodes
    rescue Exception
      # fall back on standard names
      asm_package = org.objectweb.asm
      java_import asm_package.Opcodes
    end
    java_import asm_package.Label
    java_import asm_package.Type
    java_import asm_package.AnnotationVisitor
    java_import asm_package.ClassVisitor
    java_import asm_package.FieldVisitor
    java_import asm_package.MethodVisitor
    java_import asm_package.ClassReader
  end
end
