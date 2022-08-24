# How to use Pow in an API

Pow comes with plug n' play support for Phoenix as HTML web interface. API's work differently, and the developer should have full control over the flow in a proper built API. Therefore Pow encourages that you build custom controllers, and use the plug functions for API integration.

To get you started, here's the first steps to build a Pow enabled API interface.

We'll set up a [custom authorization plug](../README.md#authorization-plug) where we'll store session tokens with `Pow.Store.CredentialsCache`, and renewal tokens with `PowPersistentSession.Store.PersistentSessionCache`. The session tokens will automatically expire after 30 minutes, whereafter your client should request a new session token with the renewal token.

First you should follow the [Getting Started](../README.md#getting-started) section in README until before the `WEB_PATH/endpoint.ex` modification.

## Routes

Modify `WEB_PATH/router.ex` with API pipelines, and API endpoints for session and registration controllers:

```elixir
# lib/my_app_web/router.ex
defmodule MyAppWeb.Router do
  use MyAppWeb, :router

  # # If you wish to also use Pow in your HTML frontend with session, then you
  # # should set the `Pow.Plug.Session` plug here rather than in the endpoint:
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

Create `WEB_PATH/api_auth_plug.ex` with the following:

```elixir
# lib/my_app_web/api_auth_plug.ex
defmodule MyAppWeb.APIAuthPlug do
  @moduledoc false
  use Pow.Plug.Base

  alias Plug.Conn
  alias Pow.{Config, Plug, Store.CredentialsCache}
  alias PowPersistentSession.Store.PersistentSessionCache

  @doc """
  Fetches the user from access token.
  """
  @impl true
  @spec fetch(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def fetch(conn, config) do
    with {:ok, signed_token} <- fetch_access_token(conn),
         {:ok, token}        <- verify_token(conn, signed_token, config),
         {user, _metadata}   <- CredentialsCache.get(store_config(config), token) do
      {conn, user}
    else
      _any -> {conn, nil}
    end
  end

  @doc """
  Creates an access and renewal token for the user.

  The tokens are added to the `conn.private` as `:api_access_token` and
  `:api_renewal_token`. The renewal token is stored in the access token
  metadata and vice versa.
  """
  @impl true
  @spec create(Conn.t(), map(), Config.t()) :: {Conn.t(), map()}
  def create(conn, user, config) do
    store_config  = store_config(config)
    access_token  = Pow.UUID.generate()
    renewal_token = Pow.UUID.generate()

    conn =
      conn
      |> Conn.put_private(:api_access_token, sign_token(conn, access_token, config))
      |> Conn.put_private(:api_renewal_token, sign_token(conn, renewal_token, config))
      |> Conn.register_before_send(fn conn ->
        # The store caches will use their default `:ttl` setting. To change the
        # `:ttl`, `Keyword.put(store_config, :ttl, :timer.minutes(10))` can be
        # passed in as the first argument instead of `store_config`.
        CredentialsCache.put(store_config, access_token, {user, [renewal_token: renewal_token]})
        PersistentSessionCache.put(store_config, renewal_token, {user, [access_token: access_token]})

        conn
      end)

    {conn, user}
  end

  @doc """
  Delete the access token from the cache.

  The renewal token is deleted by fetching it from the access token metadata.
  """
  @impl true
  @spec delete(Conn.t(), Config.t()) :: Conn.t()
  def delete(conn, config) do
    store_config = store_config(config)

    with {:ok, signed_token} <- fetch_access_token(conn),
         {:ok, token}        <- verify_token(conn, signed_token, config),
         {_user, metadata}   <- CredentialsCache.get(store_config, token) do

      Conn.register_before_send(conn, fn conn ->
        PersistentSessionCache.delete(store_config, metadata[:renewal_token])
        CredentialsCache.delete(store_config, token)

        conn
      end)
    else
      _any -> conn
    end
  end

  @doc """
  Creates new tokens using the renewal token.

  The access token, if any, will be deleted by fetching it from the renewal
  token metadata. The renewal token will be deleted from the store after the
  it has been fetched.
  """
  @spec renew(Conn.t(), Config.t()) :: {Conn.t(), map() | nil}
  def renew(conn, config) do
    store_config = store_config(config)

    with {:ok, signed_token} <- fetch_access_token(conn),
         {:ok, token}        <- verify_token(conn, signed_token, config),
         {user, metadata}    <- PersistentSessionCache.get(store_config, token) do

      {conn, user} = create(conn, user, config)

      conn =
        Conn.register_before_send(conn, fn conn ->
          CredentialsCache.delete(store_config, metadata[:access_token])
          PersistentSessionCache.delete(store_config, token)

          conn
        end)

      {conn, user}
    else
      _any -> {conn, nil}
    end
  end

  defp sign_token(conn, token, config) do
    Plug.sign_token(conn, signing_salt(), token, config)
  end

  defp signing_salt(), do: Atom.to_string(__MODULE__)

  defp fetch_access_token(conn) do
    case Conn.get_req_header(conn, "authorization") do
      [token | _rest] -> {:ok, token}
      _any            -> :error
    end
  end

  defp verify_token(conn, token, config),
    do: Plug.verify_token(conn, signing_salt(), token, config)

  defp store_config(config) do
    backend = Config.get(config, :cache_store_backend, Pow.Store.Backend.EtsCache)

    [backend: backend, pow_config: config]
  end
end
```

The above module includes renewal logic, and will return both an auth token and renewal token when a session is created.

## API authorization error handler

Create `WEB_PATH/api_auth_error_handler.ex` with the following:

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

Create `WEB_PATH/controllers/api/v1/registration_controller.ex`:

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
        json(conn, %{data: %{access_token: conn.private.api_access_token, renewal_token: conn.private.api_renewal_token}})

      {:error, changeset, conn} ->
        errors = Changeset.traverse_errors(changeset, &ErrorHelpers.translate_error/1)

        conn
        |> put_status(500)
        |> json(%{error: %{status: 500, message: "Couldn't create user", errors: errors}})
    end
  end
end
```

Create `WEB_PATH/controllers/api/v1/session_controller.ex`:

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
        json(conn, %{data: %{access_token: conn.private.api_access_token, renewal_token: conn.private.api_renewal_token}})

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
        json(conn, %{data: %{access_token: conn.private.api_access_token, renewal_token: conn.private.api_renewal_token}})
    end
  end

  @spec delete(Conn.t(), map()) :: Conn.t()
  def delete(conn, _params) do
    conn
    |> Pow.Plug.delete()
    |> json(%{data: %{}})
  end
end
```

That's it!

You can now set up your client to connect to your API and generate session tokens. The session and renewal token should be send with the `authorization` header. When you receive a 401 error, you should renew the session with the renewal token and then try again.

You can run the following curl commands to test it out:

```bash
$ curl -X POST -d "user[email]=test@example.com&user[password]=secret1234&user[password_confirmation]=secret1234" http://localhost:4000/api/v1/registration
{"data":{"renewal_token":"RENEW_TOKEN","access_token":"AUTH_TOKEN"}}

$ curl -X POST -d "user[email]=test@example.com&user[password]=secret1234" http://localhost:4000/api/v1/session
{"data":{"renewal_token":"RENEW_TOKEN","access_token":"AUTH_TOKEN"}}

$ curl -X DELETE -H "Authorization: AUTH_TOKEN" http://localhost:4000/api/v1/session
{"data":{}}

$ curl -X POST -H "Authorization: RENEW_TOKEN" http://localhost:4000/api/v1/session/renew
{"data":{"renewal_token":"RENEW_TOKEN","access_token":"AUTH_TOKEN"}}
```

## OAuth 2.0

You may notice that the renew mechanism looks like refresh tokens in OAuth 2.0, and that's because the above setup is very similar since we use short lived session ids. In some cases it may make more sense to set up an OAuth 2.0 server rather than using the above setup.

## Test modules

```elixir
# test/my_app_web/api_auth_plug_test.exs
defmodule MyAppWeb.APIAuthPlugTest do
  use MyAppWeb.ConnCase
  doctest MyAppWeb.APIAuthPlug

  alias MyAppWeb.{APIAuthPlug, Endpoint}
  alias MyApp.{Repo, Users.User}
  alias Plug.Conn

  @pow_config [otp_app: :my_app]

  setup %{conn: conn} do
    conn = %{conn | secret_key_base: Endpoint.config(:secret_key_base)}
    user = Repo.insert!(%User{id: 1, email: "test@example.com"})

    {:ok, conn: conn, user: user}
  end

  test "can create, fetch, renew, and delete session", %{conn: conn, user: user} do
    assert {_res_conn, nil} = run(APIAuthPlug.fetch(conn, @pow_config))

    assert {res_conn, ^user} = run(APIAuthPlug.create(conn, user, @pow_config))
    assert %{private: %{api_access_token: access_token, api_renewal_token: renewal_token}} = res_conn

    assert {_res_conn, nil} = run(APIAuthPlug.fetch(with_auth_header(conn, "invalid"), @pow_config))
    assert {_res_conn, ^user} = run(APIAuthPlug.fetch(with_auth_header(conn, access_token), @pow_config))
    assert {res_conn, ^user} = run(APIAuthPlug.renew(with_auth_header(conn, renewal_token), @pow_config))
    assert %{private: %{api_access_token: renewed_access_token, api_renewal_token: renewed_renewal_token}} = res_conn

    assert {_res_conn, nil} = run(APIAuthPlug.fetch(with_auth_header(conn, access_token), @pow_config))
    assert {_res_conn, nil} = run(APIAuthPlug.renew(with_auth_header(conn, renewal_token), @pow_config))
    assert {_res_conn, ^user} = run(APIAuthPlug.fetch(with_auth_header(conn, renewed_access_token), @pow_config))

    assert %Conn{} = run(APIAuthPlug.delete(with_auth_header(conn, "invalid"), @pow_config))
    assert {_res_conn, ^user} = run(APIAuthPlug.fetch(with_auth_header(conn, renewed_access_token), @pow_config))

    assert %Conn{} = run(APIAuthPlug.delete(with_auth_header(conn, renewed_access_token), @pow_config))
    assert {_res_conn, nil} = run(APIAuthPlug.fetch(with_auth_header(conn, renewed_access_token), @pow_config))
    assert {_res_conn, nil} = run(APIAuthPlug.renew(with_auth_header(conn, renewed_renewal_token), @pow_config))
  end

  defp run({conn, value}), do: {run(conn), value}
  defp run(conn), do: Conn.send_resp(conn, 200, "")

  defp with_auth_header(conn, token), do: Plug.Conn.put_req_header(conn, "authorization", token)
end
```

```elixir
# test/my_app_web/controllers/api/v1/registration_controller_test.exs
defmodule MyAppWeb.API.V1.RegistrationControllerTest do
  use MyAppWeb.ConnCase

  @password "secret1234"

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => @password, "password_confirmation" => @password}}
    @invalid_params %{"user" => %{"email" => "invalid", "password" => @password, "password_confirmation" => ""}}

    test "with valid params", %{conn: conn} do
      conn = post(conn, Routes.api_v1_registration_path(conn, :create, @valid_params))

      assert json = json_response(conn, 200)
      assert json["data"]["access_token"]
      assert json["data"]["renewal_token"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post(conn, Routes.api_v1_registration_path(conn, :create, @invalid_params))

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

  @password "secret1234"

  setup do
    user =
      %User{}
      |> User.changeset(%{email: "test@example.com", password: @password, password_confirmation: @password})
      |> Repo.insert!()

    {:ok, user: user}
  end

  describe "create/2" do
    @valid_params %{"user" => %{"email" => "test@example.com", "password" => @password}}
    @invalid_params %{"user" => %{"email" => "test@example.com", "password" => "invalid"}}

    test "with valid params", %{conn: conn} do
      conn = post(conn, Routes.api_v1_session_path(conn, :create, @valid_params))

      assert json = json_response(conn, 200)
      assert json["data"]["access_token"]
      assert json["data"]["renewal_token"]
    end

    test "with invalid params", %{conn: conn} do
      conn = post(conn, Routes.api_v1_session_path(conn, :create, @invalid_params))

      assert json = json_response(conn, 401)
      assert json["error"]["message"] == "Invalid email or password"
      assert json["error"]["status"] == 401
    end
  end

  describe "renew/2" do
    setup %{conn: conn} do
      authed_conn = post(conn, Routes.api_v1_session_path(conn, :create, @valid_params))

      {:ok, renewal_token: authed_conn.private[:api_renewal_token]}
    end

    test "with valid authorization header", %{conn: conn, renewal_token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", token)
        |> post(Routes.api_v1_session_path(conn, :renew))

      assert json = json_response(conn, 200)
      assert json["data"]["access_token"]
      assert json["data"]["renewal_token"]
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
    setup %{conn: conn} do
      authed_conn = post(conn, Routes.api_v1_session_path(conn, :create, @valid_params))

      {:ok, access_token: authed_conn.private[:api_access_token]}
    end

    test "invalidates", %{conn: conn, access_token: token} do
      conn =
        conn
        |> Plug.Conn.put_req_header("authorization", token)
        |> delete(Routes.api_v1_session_path(conn, :delete))

      assert json = json_response(conn, 200)
      assert json["data"] == %{}
    end
  end
end
```
