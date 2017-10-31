defmodule ElixirSense.Mixfile do
  @moduledoc false
  use Mix.Project

  def project do
    [app: :elixir_sense,
     version: "1.0.1",
     elixir: "~> 1.5",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail": :test, "coveralls.html": :test],
     dialyzer: [
       flags: ["-Wunmatched_returns", "-Werror_handling", "-Wrace_conditions", "-Wunderspecs", "-Wno_match"]
     ],
     deps: deps(),
     docs: docs(),
     description: description(),
     package: package(),
   ]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:excoveralls, "~> 0.6", only: :test},
    {:dialyxir, "~> 0.4", only: [:dev]},
    {:credo, "~> 0.8.4", only: [:dev]},
    {:ex_doc, "~> 0.14", only: [:dev]}]
  end

  defp docs do
    [main: "ElixirSense"]
  end

  defp description do
    """
    An API/Server for Elixir projects that provides context-aware information
    for code completion, documentation, go/jump to definition, signature info
    and more.
    """
  end

  defp package do
    [maintainers: ["Marlus Saraiva (@msaraiva)"],
     licenses: ["MIT"],
     links: %{"GitHub" => "https://github.com/msaraiva/elixir_sense"}]
  end

end
