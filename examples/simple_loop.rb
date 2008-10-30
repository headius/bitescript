require 'jvmscript'

include JVMScript

fb = FileBuilder.build('simple_loop.rb') do
  public_class "SimpleLoop" do
    public_static_method "main", void, string[] do
      aload 0
      push_int 0
      aaload
      top = label
      top.set!
      dup
      aprintln
      goto top
      returnvoid
    end
  end
end

fb.generate do |filename, class_builder|
  File.open(filename, 'w') do |file|
    file.write(class_builder.generate)
  end
end
