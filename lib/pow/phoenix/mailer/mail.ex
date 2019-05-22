defmodule Pow.Phoenix.Mailer.Mail do
  @moduledoc """
  Module that renders html and text version of e-mails.

  When a new email is generated, `subject/2` and `render/2` with both text and
  html version will be called on the view.

  If you wish to modify `assigns` before your custom email templates are
  rendered, then you should update your `:mailer_view` macro with and
  `assigns/2` method:

    defmodule MyAppWeb do
      # ...

      def mailer_view do
        quote do
          use Phoenix.View, root: "lib/my_app_web/templates",
                            namespace: MyAppWeb

          use Phoenix.HTML

          def assigns(_template, assigns), do: Keyword.put(assigns, :layout, {MyAppWeb.LayoutView, :email})
        end
      end

      # ...

    end

  You can also add the `assigns/2` method to individual views:

    defmodule MyAppWeb.PowEmailConfirmation.MailerView do
      @moduledoc false
      use MyAppWeb, :mailer_view

      def assigns(_template, assigns), do: Keyword.put(assigns, :layout, {MyAppWeb.LayoutView, :email})
    end
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
    view_module  = Pow.Phoenix.ViewHelpers.build_view_module(view_module, web_module)
    assigns      = maybe_assigns(view_module, template, assigns)
    view_assigns = Keyword.merge([conn: conn, user: user], assigns)

    subject = view_module.subject(template, view_assigns)
    text    = view_module.render("#{template}.text", view_assigns)
    html    =
      "#{template}.html"
      |> view_module.render(view_assigns)
      |> Phoenix.Template.HTML.encode_to_iodata!()
      |> IO.iodata_to_binary()

    struct(__MODULE__, user: user, subject: subject, text: text, html: html, assigns: assigns)
  end

  def maybe_assigns(view_module, template, assigns) do
    if function_exported?(view_module, :assigns, 2) do
      view_module.assigns(template, assigns)
    else
      assigns
    end
  end
end
