# How to use Pow in an API

Pow comes with plug n' play support for Phoenix as HTML web interface. API's work differently, and the developer should have full control over the flow in a proper built API. Therefore Pow encourages that you build custom controllers, and use the plug methods for API integration.

To get you started, here's the first steps to build a Pow enabled API interface.

We'll set up a [custom authorization plug](../README.md#authorization-plug) where we'll store session tokens with `Pow.Store.CredentialsCache`, and renewal tokens with `PowPersistentSession.Store.PersistentSessionCache`. The session tokens will automatically expire after 30 minutes, whereafter your client should request a new session token with the renewal token.

First you should follow the [Getting Started](../README.md#getting-started) section in README until before the `WEB_PATH/endpoint.ex` modification.

## Routes

Modify `lib/my_app_web/router.ex` with API pipelines, and API endpoints for session and registration controllers:

```elixir
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # # If you wish to also use Pow in your HTML frontend with session, then you
  # # should set the `Pow.Plug.Session method here rather than in the endpoint:
  # pipeline :browser do
  #   plug :accepts, ["html"]
  #   plug :fetch_session
  #   plug :fetch_flash
  #   plug Phoenix.LiveView.Flash
  #   plug :protect_from_forgery
  #   plug :put_secure_browser_headers
  #   plug Pow.Plug.Session, otp_app: :my_app
  # end

  pipeline :api do
    plug :accepts, ["json"]
    plug MyAppWeb.APIAuthPlug, otp_app: :my_app
  end

  pipeline :api_protected do
    plug Pow.Plug.RequireAuthenticated, error_handler: MyAppWeb.APIAuthErrorHandler
  end

  # ...

  scope "/api/v1", MyAppWeb.API.V1, as: :api_v1 do
    pipe_through :api

    resources "/registration", RegistrationController, singleton: true, only: [:create]
    resources "/session", SessionController, singleton: true, only: [:create, :delete]
    post "/session/renew", SessionController, :renew
  end

  scope "/api/v1", MyAppWeb.API.V1, as: :api_v1 do
    pipe_through [:api, :api_protected]

    # Your protected API endpoints here
  end

  # ... routes
end
```

As you can see, the above also shows how you can set up the browser pipeline in case you also have a web interface. You should put the `Pow.Plug.Session` plug there instead of in `WEB_PATH/endpoint.ex`.

## API authorization plug for Pow

Create `lib/my_app_web/api_auth_plug.ex` with the following:

```elixir
defmodule MyAppWeb.APIAuthPlug do
  @moduledoc false
  use Pow.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Store.CredentialsCache}
  alias PowPersistentSession.Store.PersistentSessionCache

  @impl true
  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    token = fetch_auth_token(conn)

    config
    |> store_config()
    |> CredentialsCache.get(token)
    |> case do
      :not_found        -> {conn, nil}
      {user, _metadata} -> {conn, user}
    end
  end

  @impl true
  @spec create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    store_config = store_config(config)
    token        = Pow.UUID.generate()
    renew_token  = Pow.UUID.generate()
    conn         =
      conn
      |> Conn.put_private(:api_auth_token, token)
      |> Conn.put_private(:api_renew_token, renew_token)

    CredentialsCache.put(store_config, token, {user, []})
    PersistentSessionCache.put(store_config, renew_token, {[id: user.id], []})

    {conn, user}
  end
  
  @impl true
  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config) do
    token = fetch_auth_token(conn)

    config
    |> store_config()
    |> CredentialsCache.delete(token)

    conn
  end
  
  @doc """
  Create a new token with the provided authorization token.
  
  The renewal authorization token will be deleted from the store after the user id has been fetched.
  """
  @spec renew(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def renew(conn, config) do
    renew_token  = fetch_auth_token(conn)
    store_config = store_config(config)
    res          = PersistentSessionCache.get(store_config, renew_token)

    PersistentSessionCache.delete(store_config, renew_token)

    case res do
      :not_found -> {conn, nil}
      res        -> load_and_create_session(conn, res, config)
    end
  end
  
  defp load_and_create_session(conn, {clauses, _metadata}, config) do
    case Pow.Operations.get_by(clauses, config) do
      nil  -> {conn, nil}
      user -> create(conn, user, config)
    end
  end

  defp fetch_auth_token(conn) do
    conn
    |> Plug.Conn.get_req_header("authorization")
    |> List.first()
  end
  
  defp store_config(config) do
    backend = Config.get(config, :cache_store_backend, Pow.Store.Backend.EtsCache)

    [backend: backend]
  end
end
```

The above module includes renewal logic, and will return both an auth token and renewal token when a session is created. Be aware that the delete method doesn't invalidate the renewal token, since we only receive the auth token.

## API authorization error handler

Create `lib/my_app_web/api_auth_error_handler.ex` with the following:

```elixir
defmodule MyAppWeb.APIAuthErrorHandler do
  use MyAppWeb, :controller
  alias Plug.Conn

  @spec call(Conn.t(), :not_authenticated) :: Conn.t()
  def call(conn, :not_authenticated) do
    conn
    |> put_status(401)
    |> json(%{error: %{code: 401, message: "Not authenticated"}})
  end
end
```

Now the protected routes will return a 401 error when an invalid token is used.

## Add API controllers

Create `lib/my_app_web/controllers/api/v1/registration_controller.ex`:

```elixir
defmodule MyAppWeb.API.V1.RegistrationController do
  use MyAppWeb, :controller

  alias Ecto.Changeset
  alias Plug.Conn
  alias MyAppWeb.ErrorHelpers

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    conn
    |> Pow.Plug.create_user(user_params)
    |> case do
      {:ok, _user, conn} ->
        json(conn, %{data: %{token: conn.private[:api_auth_token], renew_token: conn.private[:api_renew_token]}})

      {:error, changeset, conn} ->
        errors = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)

        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "Couldn't create user", errors: errors}})
    end
  end
end
```

Create `lib/my_app_web/controllers/api/v1/session_controller.ex`:

```elixir
defmodule MyAppWeb.API.V1.SessionController do
  use MyAppWeb, :controller

  alias MyAppWeb.APIAuthPlug
  alias Plug.Conn

  @spec create(Conn.t(), map()) :: Conn.t()
  def create(conn, %{"user" => user_params}) do
    conn
    |> Pow.Plug.authenticate_user(user_params)
    |> case do
      {:ok, conn} ->
        json(conn, %{data: %{token: conn.private[:api_auth_token], renew_token: conn.private[:api_renew_token]}})

      {:error, conn} ->
        conn
        |> put_status(401)
        |> json(%{error: %{status: 401, message: "Invalid email or password"}})
    end
  end

  @spec renew(Conn.t(), map()) :: Conn.t()
  def renew(conn, _params) do
    config = Pow.Plug.fetch_config(conn)

    conn
    |> APIAuthPlug.renew(config)
    |> case do
      {conn, nil} ->
        conn
        |> put_status(401)
        |> json(%{error: %{status: 401, message: "Invalid token"}})

      {conn, _user} ->
        json(conn, %{data: %{token: conn.private[:api_auth_token], renew_token: conn.private[:api_renew_token]}})
    end
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> Pow.Plug.delete()
    |> json(conn, %{data: %{}})
  end
end
```

That's it!

You can now set up your client to connect to your API and generate session tokens. The session and renewal token should be send with the `authorization` header. When you receive a 401 error, you should renew the session with the renewal token and then try again.

You can run the following curl methods to test it out:

```bash
$ curl -X POST -d "user[email]=test@example.com&user[password]=secret1234&user[password_confirmation]=secret1234" http://localhost:4000/api/v1/registration
{"data":{"renew_token":"RENEW_TOKEN","token":"AUTH_TOKEN"}}

$ curl -X POST -d "user[email]=test@example.com&user[password]=secret1234" http://localhost:4000/api/v1/session
{"data":{"renew_token":"RENEW_TOKEN","token":"AUTH_TOKEN"}}

$ curl -X DELETE -H "Authorization: AUTH_TOKEN" http://localhost:4000/api/v1/session
{"data":{}}

$ curl -X POST -H "Authorization: RENEW_TOKEN" http://localhost:4000/api/v1/session/renew
{"data":{"renew_token":"RENEW_TOKEN","token":"AUTH_TOKEN"}}
```

## OAuth 2.0

You may notice that the renew mechanism looks like refresh tokens in OAuth 2.0, and that's because the above setup is very similar since we use short lived session ids. In some cases it may make more sense to set up an OAuth 2.0 server rather than using the above setup.

## Test modules

```elixir
# test/my_app_web/api_auth_plug_test.exs
defmodule MyAppWeb.APIAuthPlugTest do
  use MyAppWeb.ConnCase
  doctest MyAppWeb.APIAuthPlug

  alias MyAppWeb.APIAuthPlug
  alias MyApp.{Repo, Users.User}

  @pow_config [otp_app: :my_app]

  test "can fetch, create, delete, and renew session for user", %{conn: conn} do
    user = Repo.insert!(%User{id: 1, email: "test@example.com"})

    assert {_conn, nil} = APIAuthPlug.fetch(conn, @pow_config)

    assert {new_conn, _user} = APIAuthPlug.create(conn, user, @pow_config)
    :timer.sleep(100)
    assert auth_token = new_conn.private[:api_auth_token]
    assert renew_token = new_conn.private[:api_renew_token]

    auth_conn = Plug.Conn.put_req_header(conn, "authorization", auth_token)
    assert {_conn, fetched_user} = APIAuthPlug.fetch(auth_conn, @pow_config)
    assert fetched_user.id == user.id

    APIAuthPlug.delete(auth_conn, @pow_config)
    :timer.sleep(100)
    assert {_conn, nil} = APIAuthPlug.fetch(auth_conn, @pow_config)

    renew_conn = Plug.Conn.put_req_header(conn, "authorization", renew_token)
    assert {new_conn, user} = APIAuthPlug.renew(renew_conn, @pow_config)
    assert auth_token = new_conn.private[:api_auth_token]
    :timer.sleep(100)

    auth_conn = Plug.Conn.put_req_header(conn, "authorization", auth_token)

    assert {_conn, nil} = APIAuthPlug.renew(renew_conn, @pow_config)
    assert {_conn, fetched_user} = APIAuthPlug.fetch(auth_conn, @pow_config)
    assert fetched_user.id == user.id
  end
end
```

```elixir
# test/my_app_web/controllers/api/v1/registration_controller_test.exs
defmodule MyAppWeb.API.V1.RegistrationControllerTest do
  use MyAppWeb.ConnCase

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret1234", "password_confirmation" => "secret1234"}}
    @invalid_params %{"user" => %{"email" => "invalid", "password" => "secret1234", "password_confirmation" => ""}}

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.api_v1_registration_path(conn, :create, @valid_params)

      assert json = json_response(conn, 200)
      assert json["data"]["token"]
      assert json["data"]["renew_token"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.api_v1_registration_path(conn, :create, @invalid_params)

      assert json = json_response(conn, 500)

      assert json["error"]["message"] == "Couldn't create user"
      assert json["error"]["status"] == 500
      assert json["error"]["errors"]["password_confirmation"] == ["does not match confirmation"]
      assert json["error"]["errors"]["email"] == ["has invalid format"]
    end
  end
end
```

```elixir
# test/my_app_web/controllers/api/v1/session_controller_test.exs
defmodule MyAppWeb.API.V1.SessionControllerTest do
  use MyAppWeb.ConnCase

  alias MyApp.{Repo, Users.User}
  alias MyAppWeb.APIAuthPlug
  alias Pow.Ecto.Schema.Password

  @pow_config [otp_app: :my_app]

  setup %{conn: conn} do
    user = Repo.insert!(%User{email: "test@example.com", password_hash: Password.pbkdf2_hash("secret1234")})

    {:ok, conn: conn, user: user}
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => "secret1234"}}
    @invalid_params %{"user" => %{"email" => "test@example.com", "password" => "invalid"}}

    test "with valid params", %{conn: conn} do
      conn = post conn, Routes.api_v1_session_path(conn, :create, @valid_params)

      assert json = json_response(conn, 200)
      assert json["data"]["token"]
      assert json["data"]["renew_token"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post conn, Routes.api_v1_session_path(conn, :create, @invalid_params)

      assert json = json_response(conn, 401)

      assert json["error"]["message"] == "Invalid email or password"
      assert json["error"]["status"] == 401
    end
  end

  describe "renew/2" do
    setup %{conn: conn, user: user} do
      {authed_conn, _user} = APIAuthPlug.create(conn, user, @pow_config)

      :timer.sleep(100)

      {:ok, conn: conn, renew_token: authed_conn.private[:api_renew_token]}
    end

    test "with valid authorization header", %{conn: conn, renew_token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", token)
        |> post(Routes.api_v1_session_path(conn, :renew))

      assert json = json_response(conn, 200)
      assert json["data"]["token"]
      assert json["data"]["renew_token"]
    end

    test "with invalid authorization header", %{conn: conn} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", "invalid")
        |> post(Routes.api_v1_session_path(conn, :renew))

      assert json = json_response(conn, 401)

      assert json["error"]["message"] == "Invalid token"
      assert json["error"]["status"] == 401
    end
  end

  describe "delete/2" do
    setup %{conn: conn, user: user} do
      {authed_conn, _user} = APIAuthPlug.create(conn, user, @pow_config)

      :timer.sleep(100)

      {:ok, conn: conn, auth_token: authed_conn.private[:api_auth_token]}
    end

    test "invalidates", %{conn: conn, auth_token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", token)
        |> delete(Routes.api_v1_session_path(conn, :delete))

      assert json_response(conn, 200)
      :timer.sleep(100)

      assert {_conn, nil} = APIAuthPlug.fetch(conn, @pow_config)
    end
  end
end
```
