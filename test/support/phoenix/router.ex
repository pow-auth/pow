defmodule Authex.Test.Phoenix.Router do
  use Phoenix.Router
  use Authex.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/" do
    pipe_through :browser

    authex_routes()
  end
end
