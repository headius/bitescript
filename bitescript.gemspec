# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{bitescript}
  s.version = "0.1.0"
  s.authors = ["Charles Oliver Nutter", "Ryan Brown"]
  s.date = Time.now.strftime('%Y-%m-%d')
  s.description = %q{BiteScript is a Ruby DSL for generating Java bytecode and classes.}
  s.email = ["headius@headius.com", "ribrdb@gmail.com"]
  s.executables = ["bite", "bitec"]
  s.extra_rdoc_files = Dir['*.txt']
  s.files = Dir['{bin,examples,lib,nbproject,test}/**/*'] + Dir['{*.txt,*.gemspec,Rakefile}']
  s.homepage = %q{http://github.com/headius/bitescript}
  s.rdoc_options = ["--main", "README.txt"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{jruby-extras}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{BiteScript is a Ruby DSL for generating Java bytecode.}
  s.test_files = Dir["test/test*.rb"]
end
