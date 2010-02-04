require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
$: << './lib'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.test_files = FileList["test/**/*.rb"]
end
