import Config

if Mix.env() == :test do
  import_config "test.exs"
end
