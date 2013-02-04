require 'rake'
require 'rake/testtask'
require 'rdoc/task'

task :default => :test

Rake::TestTask.new :test do |t|
  t.libs << "lib"
  t.test_files = FileList["test/**/*.rb"]
end
