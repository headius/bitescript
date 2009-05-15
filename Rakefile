require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'hoe'
$: << './lib'
require 'bitescript.rb'

Hoe.new('bitescript', BiteScript::VERSION) do |p|
  p.rubyforge_name = 'jruby-extras'
  p.url = "http://kenai.com/projects/jvmscript"
  p.author = "charles.nutter@sun.com"
  p.summary = "BiteScript is a Ruby DSL for generating Java bytecode."
  p.changes = p.paragraphs_of('History.txt', 0..1).join("\n\n")
  p.developer('Charles Oliver Nutter', 'charles.nutter@sun.com')
end

task :default => :test
