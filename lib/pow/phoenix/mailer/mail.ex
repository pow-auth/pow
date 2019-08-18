defmodule Pow.Phoenix.Mailer.Mail do
  @moduledoc """
  Module that renders html and text version of e-mails.

  ## Custom layout

  By default no layout is used to render the templates. You can set
  `:pow_mailer_layout` in `conn.private` the same way as you set
  `:phoenix_layout` to render a layout for the template.

  This is how you can set the mailer layout:

      defmodule MyAppWeb.Router do
        # ...

        pipeline :pow_email_layout do
          plug :put_pow_mailer_layout, {MyAppWeb.LayoutView, :email}
        end

        # ...

        scope "/" do
          pipe_through [:browser, :pow_email_layout]

          pow_routes()
        end

        # ...

        defp put_pow_mailer_layout(conn, layout), do: put_private(conn, :pow_mailer_layout, layout)
      end

  You can use atom or binary as template. If a binary is used then only format
  that it ends with will be used, e.g. using "email.html" will result in no
  text layout being used.
  """
  alias Plug.Conn
  alias Pow.{Config, Phoenix.ViewHelpers, Plug}

  @type t :: %__MODULE__{}

  defstruct [:user, :subject, :text, :html, :assigns]

  @doc """
  Returns a populated `%Pow.Phoenix.Mailer.Mail{}` map.

  If the configuration has `:web_mailer_module`, it will be used to find the
  template view module to call.
  """
  @spec new(Conn.t(), map(), {module(), atom()}, Keyword.t()) :: t()
  def new(conn, user, {view_module, template}, assigns) do
    config       = Plug.fetch_config(conn)
    web_module   = Config.get(config, :web_mailer_module)
    view_assigns = Keyword.merge([conn: conn, user: user], assigns)
    view_module  = ViewHelpers.build_view_module(view_module, web_module)

    subject = render_subject(view_module, template, view_assigns)
    text    = render(view_module, template, conn, view_assigns, :text)
    html    = render(view_module, template, conn, view_assigns, :html)

    struct(__MODULE__, user: user, subject: subject, text: text, html: html, assigns: assigns)
  end

  defp render_subject(view_module, template, assigns) do
    view_module.subject(template, assigns)
  end

  defp render(view_module, template, conn, assigns, format) do
    view_assigns = prepare_assigns(conn, assigns, format)

    Phoenix.View.render_to_string(view_module, "#{template}.#{format}", view_assigns)
  end

  defp prepare_assigns(conn, assigns, format) do
    layout =
      conn.private
      |> Map.get(:pow_mailer_layout, false)
      |> layout(format)

    assigns
    |> Keyword.put(:layout, layout)
    |> Keyword.merge(assigns)
  end

  defp layout({view, layout}, format) when is_atom(layout), do: {view, "#{layout}.#{format}"}
  defp layout({view, layout}, format) when is_binary(layout) do
    case String.ends_with?(layout, ".#{format}") do
      true  -> {view, layout}
      false -> false
    end
  end
  defp layout(false, _format), do: false
end
