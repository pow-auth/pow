defmodule Mix.Authex.Context do
  @moduledoc """
  A helper module for fetching app context in mix tasks.
  """

  @spec context_app :: atom() | no_return
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
    Mix.Project.config |> Keyword.fetch!(:app)
  end

  defp otp_app() do
    Mix.Project.config()
    |> Keyword.fetch!(:app)
  end

  @spec context_base(atom()) :: binary()
  def context_base(app) do
    case Application.get_env(app, :namespace, app) do
      ^app -> app |> to_string() |> Macro.camelize()
      mod  -> mod |> inspect()
    end
  end

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
        Mix.raise("No directory for context_app #{inspect app} found in #{this_otp_app}'s deps.")
    end
  end
end
