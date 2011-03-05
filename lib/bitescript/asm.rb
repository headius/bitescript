require 'java'

module BiteScript
  module ASM
    begin
      # try mangled names for the version included with JRuby <=1.6.0.RC2
      java.lang.Class.for_name 'jruby.objectweb.asm.Opcodes'
      
      # no error, proceed with mangled name
      asm_package = Java::jruby.objectweb.asm
      java_import asm_package.Opcodes
    rescue Exception
      begin
        # try mangled names for the version included with JRuby >=1.6.0.RC3
        java.lang.Class.for_name 'org.jruby.org.objectweb.asm.Opcodes'
        
        # no error, proceed with mangled name
        asm_package = Java::org.jruby.org.objectweb.asm
        java_import asm_package.Opcodes
      rescue
        # fall back on standard names
        asm_package = org.objectweb.asm
        java_import asm_package.Opcodes
      end
    end
    java_import asm_package.Label
    java_import asm_package.Type
    java_import asm_package.AnnotationVisitor
    java_import asm_package.ClassVisitor
    java_import asm_package.FieldVisitor
    java_import asm_package.MethodVisitor
    java_import asm_package.ClassReader
    java_import asm_package.ClassWriter
    java_import asm_package.util.CheckClassAdapter
    java_import asm_package.signature.SignatureReader
    java_import asm_package.signature.SignatureVisitor
    java_import asm_package.signature.SignatureWriter
  end
end
