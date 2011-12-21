$: << File.dirname(__FILE__)
begin
  require 'bitescript/asm'
  require 'bitescript/signature'
  require 'bitescript/bytecode'
  require 'bitescript/builder'
  require 'bitescript/mirror'
rescue LoadError
  require 'bitescript/asm3/asm'
  require 'bitescript/asm3/signature'
  require 'bitescript/asm3/bytecode'
  require 'bitescript/asm3/builder'
  require 'bitescript/asm3/mirror'
end

module BiteScript
  include BiteScript::ASM
  JAVA1_4 = Opcodes::V1_4
  JAVA1_5 = Opcodes::V1_5
  JAVA1_6 = Opcodes::V1_6
  JAVA1_7 = Opcodes::V1_7
  JAVA1_8 = defined?(Opcodes::V1_8) ? Opcodes::V1_8 : Opcodes::V1_7

  class << self
    attr_accessor :bytecode_version

    # Default to JVM version we're running on
    spec_version = ENV_JAVA['java.specification.version']
    BiteScript.bytecode_version = BiteScript.const_get("JAVA#{spec_version.gsub('.', '_')}")
  end
end
