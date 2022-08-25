defmodule Mix.Pow do
  @moduledoc """
  Utilities module for mix tasks.
  """
  alias Mix.{Dep, Project}

  @doc """
  Raises an exception if the project is an umbrella app.
  """
  @spec no_umbrella!(binary()) :: :ok
  def no_umbrella!(task) do
    if Project.umbrella?() do
      Mix.raise("mix #{task} can only be run inside an application directory")
    end

    :ok
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `ensure_ecto!` or `ensure_phoenix!` instead"
  @spec ensure_dep!(binary(), atom(), OptionParser.argv()) :: :ok
  def ensure_dep!(task, dep, _args) do
    []
    |> Dep.load_on_environment()
    |> top_level_dep_in_deps?(dep)
    |> case do
      true ->
        :ok

      false ->
        Mix.raise("mix #{task} can only be run inside an application directory that has #{inspect dep} as dependency")
    end
  end

  @doc """
  Raises an exception if application doesn't have Ecto as dependency.
  """
  @spec ensure_ecto!(binary(), OptionParser.argv()) :: :ok
  def ensure_ecto!(task, _args) do
    deps = Dep.load_on_environment([])

    cond do
      top_level_dep_in_deps?(deps, :ecto) -> :ok
      top_level_dep_in_deps?(deps, :ecto_sql) -> :ok
      true -> Mix.raise("mix #{task} can only be run inside an application directory that has :ecto or :ecto_sql as dependency")
    end
  end

  defp top_level_dep_in_deps?(deps, dep) do
    Enum.any?(deps, fn
      %Mix.Dep{app: ^dep, top_level: true} -> true
      _any -> false
    end)
  end

  @doc """
  Raises an exception if application doesn't have Phoenix as dependency.
  """
  @spec ensure_phoenix!(binary(), OptionParser.argv()) :: :ok
  def ensure_phoenix!(task, _args) do
    []
    |> Dep.load_on_environment()
    |> top_level_dep_in_deps?(:phoenix)
    |> case do
      true -> :ok
      false -> Mix.raise("mix #{task} can only be run inside an application directory that has :phoenix as dependency")
    end
  end

  @doc """
  Parses argument options into a map.
  """
  @spec parse_options(OptionParser.argv(), Keyword.t(), Keyword.t()) :: {map(), OptionParser.argv(), OptionParser.errors()}
  def parse_options(args, switches, default_opts) do
    generator_opts = parse_context_app(Application.get_env(otp_app(), :generators, []))
    default_opts   = Keyword.merge(default_opts, generator_opts)

    {opts, parsed, invalid} = OptionParser.parse(args, switches: switches)
    default_opts            = to_map(default_opts)
    opts                    = context_app_to_atom(to_map(opts))
    config                  = Map.merge(default_opts, opts)

    {config, parsed, invalid}
  end

  defp parse_context_app(options) do
    case options[:context_app] do
      {context_app, _path} -> Keyword.put(options, :context_app, context_app)
      _context_app         -> options
    end
  end

  defp to_map(keyword) do
    Enum.reduce(keyword, %{}, fn {key, value}, map ->
      case Map.get(map, key) do
        nil ->
          Map.put(map, key, value)

        existing_value ->
          value = List.wrap(existing_value) ++ [value]
          Map.put(map, key, value)
      end
    end)
  end

  defp context_app_to_atom(%{context_app: context_app} = config),
    do: Map.put(config, :context_app, String.to_atom(context_app))
  defp context_app_to_atom(config),
    do: config

  @doc """
  Parses arguments into schema name and schema plural.
  """
  @spec schema_options_from_args([binary()]) :: map()
  def schema_options_from_args(_opts \\ [])
  def schema_options_from_args([schema, plural | _rest]), do: %{schema_name: schema, schema_plural: plural}
  def schema_options_from_args(_any), do: %{schema_name: "Users.User", schema_plural: "users"}

  @doc false
  @spec validate_schema_args!([binary()], binary()) :: map()
  def validate_schema_args!([schema, plural | _rest] = args, task) do
    cond do
      not schema_valid?(schema) ->
        raise_invalid_schema_args_error!("Expected the schema argument, #{inspect schema}, to be a valid module name", task)
      not plural_valid?(plural) ->
        raise_invalid_schema_args_error!("Expected the plural argument, #{inspect plural}, to be all lowercase using snake_case convention", task)
      true ->
        schema_options_from_args(args)
    end
  end
  def validate_schema_args!([_schema | _rest], task) do
    raise_invalid_schema_args_error!("Invalid arguments", task)
  end
  def validate_schema_args!([], _task), do: schema_options_from_args()

  defp schema_valid?(schema), do: schema =~ ~r/^[A-Z]\w*(\.[A-Z]\w*)*$/

  defp plural_valid?(plural), do: plural =~ ~r/^[a-z\_]*$/

  @spec raise_invalid_schema_args_error!(binary(), binary()) :: no_return()
  defp raise_invalid_schema_args_error!(msg, task) do
    Mix.raise("""
    #{msg}

    mix #{task} accepts both a module name and the plural of the resource:
        mix #{task} Users.User users
    """)
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Please use `Pow.Phoenix.parse_structure/1` instead"
  @spec context_app :: atom()
  def context_app do
    this_app = otp_app()

    this_app
    |> Application.get_env(:generators, [])
    |> Keyword.get(:context_app)
    |> case do
      nil          -> this_app
      false        -> Mix.raise("No context_app configured for current application")
      {app, _path} -> app
      app          -> app
    end
  end

  @doc false
  @spec otp_app :: atom()
  def otp_app do
    Keyword.fetch!(Mix.Project.config(), :app)
  end

  # TODO: Remove by 1.1.0
  @doc false
  @deprecated "Use `app_base/1` instead"
  @spec context_base(atom()) :: atom()
  def context_base(app), do: app_base(app)

  @doc """
  Fetches the context base module for the app.
  """
  @spec app_base(atom()) :: atom()
  def app_base(app) do
    case Application.get_env(app, :namespace, app) do
      ^app ->
        app
        |> to_string()
        |> Macro.camelize()
        |> List.wrap()
        |> Module.concat()

      mod ->
        mod
    end
  end

  @doc """
  Fetches the library path for the context app.
  """
  @spec context_lib_path(atom(), Path.t()) :: Path.t()
  def context_lib_path(ctx_app, rel_path) do
    context_app_path(ctx_app, Path.join(["lib", to_string(ctx_app), rel_path]))
  end

  defp context_app_path(ctx_app, rel_path) when is_atom(ctx_app) do
    this_app = otp_app()

    if ctx_app == this_app do
      rel_path
    else
      app_path =
        case Application.get_env(this_app, :generators)[:context_app] do
          {^ctx_app, path} -> Path.relative_to_cwd(path)
          _ -> mix_app_path(ctx_app, this_app)
        end

      Path.join(app_path, rel_path)
    end
  end

  defp mix_app_path(app, this_otp_app) do
    case Mix.Project.deps_paths() do
      %{^app => path} ->
        Path.relative_to_cwd(path)

      _deps ->
        Mix.raise("No directory for context_app #{inspect(app)} found in #{this_otp_app}'s deps.")
    end
  end

  @doc """
  Injects files with inline content
  """
  @spec inject_files([map()]) :: :ok | :error
  def inject_files(file_injections) do
    case process_file_injections(file_injections) do
      {:error, {:missing_files, file_injections}} ->
        Mix.shell().error("""
        Could not find the following file(s):

        #{Enum.map_join(file_injections, "\n", &Path.relative_to_cwd(&1.file))}
        """)

        :error

      {:error, {:invalid_files, file_injections}} ->
        Mix.shell().error("""
        Could not configure the following files:

        #{Enum.map_join(file_injections, "\n", &Path.relative_to_cwd(&1.file))}
        """)

        Mix.shell.info("""
        To complete please do the following:

        #{Enum.map_join(file_injections, "\n", & &1.instructions)}
        """)

        :ok

      {:ok, file_injections} ->
        Enum.each(file_injections, fn
          %{touched?: false, file: file} ->
            relative_path = Path.relative_to_cwd(file)

            Mix.shell().info([:yellow, "* already configured ", :reset, relative_path])

          %{touched?: true, file: file, content: content} ->
            relative_path = Path.relative_to_cwd(file)

            Mix.shell().info([:green, "* injecting ", :reset, relative_path])

            File.write!(file, content)
        end)

        :ok
    end
  end

  defp process_file_injections(file_injections) do
    with :ok             <- check_all_files_exists(file_injections),
         file_injections <- read_files(file_injections),
         :ok             <- check_all_files_can_be_updated(file_injections) do
      {:ok, Enum.map(file_injections, &prepare_content/1)}
    end
  end

  defp check_all_files_exists(file_injections) do
    case Enum.reject(file_injections, &File.exists?(&1.file)) do
      [] ->
        :ok

      file_injections ->
        {:error, {:missing_files, file_injections}}
    end
  end

  defp read_files(file_injections) do
    Enum.map(file_injections, &Map.put(&1, :content, File.read!(&1.file)))
  end

  defp check_all_files_can_be_updated(file_injections) do
    file_injections
    |> Enum.reject(fn file_injection ->
      injections = Enum.reject(file_injection.injections, & file_injection.content =~ &1.needle)

      injections == []
    end)
    |> case do
      [] -> :ok
      file_injections -> {:error, {:invalid_files, file_injections}}
    end
  end

  defp prepare_content(file_injection) do
    file_injection = Map.put(file_injection, :touched?, false)

    case Enum.reject(file_injection.injections, & file_injection.content =~ &1.test) do
      [] ->
        file_injection

      injections ->
        content = inject_content(injections, file_injection.content)

        file_injection
        |> Map.put(:content, content)
        |> Map.put(:touched?, true)
    end
  end

  defp inject_content(injections, content) do
    Enum.reduce(injections, content, fn injection, content ->
      content_lines = String.split(content, "\n")
      index = Enum.find_index(content_lines, & &1 =~ injection.needle)

      index =
        case injection[:prepend] do
          true -> previous_line_until_before_comments(content_lines, index - 1)
          _any -> index
        end

      {content_lines_before, content_lines_after} = Enum.split(content_lines, index + 1)

      [content_lines_before, [injection.content], content_lines_after]
      |> Enum.concat()
      |> Enum.join("\n")
    end)
  end

  defp previous_line_until_before_comments(content_lines, index) do
    case Enum.at(content_lines, index) do
      nil -> Mix.raise("Invalid line")
      "#" <> _string -> previous_line_until_before_comments(content_lines, index - 1)
      _string -> index
    end
  end
end
