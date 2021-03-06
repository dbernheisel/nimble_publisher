defmodule NimblePublisherTest do
  use ExUnit.Case, async: true

  doctest NimblePublisher

  defmodule Builder do
    def build(filename, attrs, body) do
      %{filename: filename, attrs: attrs, body: body}
    end
  end

  alias NimblePublisherTest.Example

  setup do
    File.rm_rf!("test/tmp")
    :code.purge(Example)
    :code.delete(Example)
    :ok
  end

  test "builds all matching entries" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/**/*.md",
        as: :examples

      assert [
               %{filename: "crlf.md"},
               %{filename: "markdown.md"},
               %{filename: "nosyntax.md"},
               %{filename: "syntax.md"}
             ] =
               @examples
               |> update_in([Access.all(), :filename], &Path.basename/1)
               |> Enum.sort_by(& &1.filename)
    end
  end

  test "converts to markdown" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/markdown.md",
        as: :examples

      assert hd(@examples).attrs == %{hello: "world"}

      assert hd(@examples).body ==
               "<p>\n  This is a markdown \n  <em>\n    document\n  </em>\n  .\n</p>\n"
    end
  end

  test "handles code blocks" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/nosyntax.md",
        as: :examples

      assert hd(@examples).attrs == %{syntax: "nohighlight"}
      assert hd(@examples).body =~ "<pre><code>IO.puts &quot;syntax&quot;</code></pre>"
    end
  end

  test "handles highlight blocks" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/syntax.md",
        as: :highlights,
        highlighters: [:makeup_elixir]

      assert hd(@highlights).attrs == %{syntax: "highlight"}
      assert hd(@highlights).body =~ "<pre><code class=\"makeup elixir\">"
    end
  end

  test "does not require recompilation unless paths changed" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/fixtures/syntax.md",
        as: :highlights,
        highlighters: [:makeup_elixir]
    end

    refute Example.__mix_recompile__?()
  end

  test "requires recompilation if paths change" do
    defmodule Example do
      use NimblePublisher,
        build: Builder,
        from: "test/tmp/**/*.md",
        as: :highlights,
        highlighters: [:makeup_elixir]
    end

    refute Example.__mix_recompile__?()

    File.mkdir_p!("test/tmp")
    File.write!("test/tmp/example.md", "done!")

    assert Example.__mix_recompile__?()
  end

  test "raises if missing separator" do
    assert_raise RuntimeError,
                 ~r/could not find separator --- in "test\/fixtures\/invalid.noseparator"/,
                 fn ->
                   defmodule Example do
                     use NimblePublisher,
                       build: Builder,
                       from: "test/fixtures/invalid.noseparator",
                       as: :example
                   end
                 end
  end

  test "raises if not a map" do
    assert_raise RuntimeError,
                 ~r/expected attributes for \"test\/fixtures\/invalid.nomap\" to return a map/,
                 fn ->
                   defmodule Example do
                     use NimblePublisher,
                       build: Builder,
                       from: "test/fixtures/invalid.nomap",
                       as: :example
                   end
                 end
  end
end
