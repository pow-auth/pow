defmodule Pow.Phoenix.Router do
  @moduledoc """
  Handles Phoenix routing for Pow.

  ## Usage

  Configure `lib/my_project_web/router.ex` the following way:

      defmodule MyAppWeb.Router do
        use MyAppWeb, :router
        use Pow.Phoenix.Router

        pipeline :browser do
          plug :accepts, ["html"]
          plug :fetch_session
          plug :fetch_flash
          plug :protect_from_forgery
          plug :put_secure_browser_headers
        end

        scope "/" do
          pipe_through :browser

          pow_routes()
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
  Pow router macro.

  Use this macro to define the Pow routes.

  ## Example

      scope "/" do
        pow_routes()
      end
  """
  defmacro pow_routes do
    quote location: :keep do
      scope "/", Pow.Phoenix, as: "pow" do
        resources "/session", SessionController, singleton: true, only: [:new, :create, :delete]
        resources "/registration", RegistrationController, singleton: true, except: [:show]
      end
    end
  end
end
