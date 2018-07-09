defmodule Authex.Test.Phoenix.Router do
  use Phoenix.Router
  use Authex.Phoenix.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers

    plug Authex.Authorization.Plug.Session,
      current_user_assigns_key: :current_user,
      session_key: "auth",
      session_store: Authex.Test.CredentialsCacheMock,
      credentials_cache_name: "credentials",
      credentials_cache_ttl: :timer.hours(48),
      users_context: Authex.Test.UsersContextMock,
      phoenix_views_namespace: Authex.Test.Phoenix
  end

  scope "/" do
    pipe_through :browser

    authex_routes()
  end
end
