require "test_helper"

class SourceTest < Minitest::Test
  A = Steep::Annotation
  T = Steep::Types

  include TestHelper

  def test_foo
    source = <<-EOF
# @type var x1: any

module Foo
  # @type var x2: any

  class Bar
    # @type instance: String
    # @type module: String.class

    # @type var x3: any
    # @type method foo: -> any
    def foo
      # @type return: any
      # @type var x4: any
      self.tap do
        # @type var x5: any
        # @type block: Integer
      end
    end

    # @type method bar: () -> any
    def bar
    end
  end
end

Foo::Bar.new
    EOF

    s = Steep::Source.parse(source, path: Pathname("foo.rb"))

    # toplevel
    assert_any s.annotations(block: s.node) do |a| a.is_a?(A::VarType) && a.var == :x1 && a.type == T::Any.new end
    # module
    assert_any s.annotations(block: s.node.children[0]) do |a| a == A::VarType.new(var: :x2, type: T::Any.new) end
    assert_nil s.annotations(block: s.node.children[0]).instance_type
    assert_nil s.annotations(block: s.node.children[0]).module_type

    # class
    class_annotations = s.annotations(block: s.node.children[0].children[1])
    assert_equal 5, class_annotations.size
    assert_equal Steep::Types::Name.instance(name: :String), class_annotations.instance_type
    assert_equal Steep::Types::Name.module(name: :String), class_annotations.module_type
    assert_includes class_annotations, A::VarType.new(var: :x3, type: T::Any.new)
    assert_includes class_annotations, A::MethodType.new(method: :foo, type: Steep::Parser.parse_method("-> any"))
    assert_includes class_annotations, A::MethodType.new(method: :bar, type: parse_method_type("() -> any"))

    # def
    foo_annotations = s.annotations(block: s.node.children[0].children[1].children[2].children[0])
    assert_equal 2, foo_annotations.size
    assert_includes foo_annotations, A::VarType.new(var: :x4, type: T::Any.new)
    assert_includes foo_annotations, A::ReturnType.new(type: T::Any.new)

    # block
    block_annotations = s.annotations(block: s.node.children[0].children[1].children[2].children[0].children[2])
    assert_equal 2, block_annotations.size
    assert_includes block_annotations, A::VarType.new(var: :x5, type: T::Any.new)
    assert_includes block_annotations, A::BlockType.new(type: T::Name.instance(name: :Integer))
  end
end
