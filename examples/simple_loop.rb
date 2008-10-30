require 'jvmscript'

include JVMScript

fb = FileBuilder.build(__FILE__) do
  public_class "SimpleLoop" do
    public_static_method "main", void, string[] do
      aload 0
      push_int 0
      aaload
      label :top
      dup
      aprintln
      goto :top
      returnvoid
    end
  end
end

fb.generate do |filename, class_builder|
  File.open(filename, 'w') do |file|
    file.write(class_builder.generate)
  end
end
