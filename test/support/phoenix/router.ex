defmodule Pow.Test.Phoenix.Router do
  @moduledoc false
  use Pow.Test.Phoenix.Web, :router
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
end
