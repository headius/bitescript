$: << File.dirname(__FILE__)
require 'bitescript/asm'
require 'bitescript/signature'
require 'bitescript/bytecode'
require 'bitescript/builder'

module BiteScript
  VERSION = '0.0.3'

  include BiteScript::ASM
  JAVA1_4 = Opcodes::V1_4
  JAVA1_5 = Opcodes::V1_5
  JAVA1_6 = Opcodes::V1_6

  class << self
    attr_accessor :bytecode_version

    BiteScript.bytecode_version = JAVA1_4
  end
end
