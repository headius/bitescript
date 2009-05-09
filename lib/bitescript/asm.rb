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
  end
end
