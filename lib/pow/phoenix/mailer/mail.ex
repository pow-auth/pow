defmodule Pow.Phoenix.Mailer.Mail do
  @moduledoc """
  Module that renders html and text version of e-mails.
  """
  alias Plug.Conn
  alias Pow.{Config, Plug}

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

    view_module = Pow.Phoenix.ViewHelpers.build_view_module(view_module, web_module)

    subject = view_module.subject(template, view_assigns)
    text    = view_module.render("#{template}.text", view_assigns)
    html    =
      "#{template}.html"
      |> view_module.render(view_assigns)
      |> Phoenix.Template.HTML.encode_to_iodata!()
      |> IO.iodata_to_binary()

    struct(__MODULE__, user: user, subject: subject, text: text, html: html, assigns: assigns)
  end
end
