defmodule ElixirSense.Core.ParserTest do
  use ExUnit.Case

  import ElixirSense.Core.Parser
  alias ElixirSense.Core.{Metadata, State.Env}

  test "parse_string creates a Metadata struct" do
    source = """
    defmodule MyModule do
      import List

    end
    """
    assert %Metadata{
      error: nil,
      mods_funs_to_positions: %{{MyModule, nil, nil} => %{positions: [{1, 11}]}},
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      },
      source: "defmodule MyModule" <> _
    } = parse_string(source, true, true, 3)
  end

  test "parse_string with syntax error" do
    source = """
    defmodule MyModule do
      import List
      Enum +
    end
    """
    assert %Metadata{
      error: nil,
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      }
    } = parse_string(source, true, true, 3)
  end

  test "parse_string with syntax error (missing param)" do
    source = """
    defmodule MyModule do
      import List
      IO.puts(:stderr, )
    end
    """
    assert %Metadata{
      error: nil,
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      }
    } = parse_string(source, true, true, 3)
  end

  test "parse_string with missing terminator \")\"" do
    source = """
    defmodule MyModule do
      import List
      func(
    end
    """
    assert %Metadata{
      error: nil,
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      }
    } = parse_string(source, true, true, 3)
  end

  test "parse_string with missing terminator \"]\"" do
    source = """
    defmodule MyModule do
      import List
      list = [
    end
    """
    assert %Metadata{
      error: nil,
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      }
    } = parse_string(source, true, true, 3)
  end

  test "parse_string with missing terminator \"}\"" do
    source = """
    defmodule MyModule do
      import List
      tuple = {
    end
    """
    assert %Metadata{
      error: nil,
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      }
    } = parse_string(source, true, true, 3)
  end

  test "parse_string with missing terminator \"end\"" do
    source = """
    defmodule MyModule do

    """
    assert parse_string(source, true, true, 2) ==
      %ElixirSense.Core.Metadata{
        error: {3,"missing terminator: end (for \"do\" starting at line 1)", ""},
        lines_to_env: %{},
        mods_funs_to_positions: %{},
        source: "defmodule MyModule do\n\n"
      }
  end

  test "parse_string ignores non existing modules in `use`" do
    source = """
    defmodule MyModule do
      use EnumFake
      import List

    end
    """
    assert %Metadata{
      error: nil,
      mods_funs_to_positions: %{{MyModule, nil, nil} => %{positions: [{1, 11}]}},
      lines_to_env: %{
        1 => %Env{imports: []},
        3 => %Env{imports: [List]}
      },
      source: "defmodule MyModule" <> _
    } = parse_string(source, true, true, 4)

  end

end
