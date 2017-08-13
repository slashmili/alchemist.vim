Code.require_file "run.exs", __DIR__
ExUnit.start()

for path <- Path.wildcard(Path.join(__DIR__, "/test/**/*.exs")) do
  Code.require_file path
end
