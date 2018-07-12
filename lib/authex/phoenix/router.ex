defmodule Authex.Phoenix.Router do
  @moduledoc """
  Handles Phoenix routing for Authex.

  ## Usage

  Configure `lib/my_project_web/router.ex` the following way:

      defmodule MyProjectWeb.Router do
        use MyProjectWeb, :router
        use Authex.Phoenix.Router

        # ...

        scope "/" do
          pipe_through :browser

          authex_routes()
        end

        # ...
      end
  """

  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
    end
  end

  @doc """
  Authex router macro.
  Use this macro to define the Authex routes.

  ## Examples:
      scope "/" do
        authex_routes()
      end
  """
  defmacro authex_routes(options \\ %{}) do
    quote location: :keep do
      options = Map.merge(%{scope: ""}, unquote(Macro.escape(options)))

      scope "/#{options[:scope]}", Authex.Phoenix, as: "authex" do
        resources "/session", SessionController, singleton: true, only: [:new, :create, :delete]
        resources "/registration", RegistrationController, singleton: true
      end
    end
  end
end
