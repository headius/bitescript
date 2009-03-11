require 'java'

module BiteScript
  module ASM
    begin
      # try mangled names for the version included with JRuby
      import "jruby.objectweb.asm.Opcodes"
      asm_package = Java::jruby.objectweb.asm
    rescue Exception
      # fall back on standard names
      import "org.objectweb.asm.Opcodes"
      asm_package = org.objectweb.asm
    end
    import asm_package.Label
    import asm_package.Type
  end
end