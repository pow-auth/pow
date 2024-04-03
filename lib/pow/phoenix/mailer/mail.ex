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

        pipeline :pow_email_layouts do
          plug :put_pow_mailer_layouts, html: {MyAppWeb.Layouts, :email}, text: {MyAppWeb.Layouts, :email_text}
        end

        # ...

        scope "/" do
          pipe_through [:browser, :pow_email_layouts]

          pow_routes()
        end

        # ...

        defp put_pow_mailer_layouts(conn, layout), do: put_private(conn, :put_pow_mailer_layouts, layouts)
      end

  If a specific format is specified, such as `html: {MyAppWeb.Layouts, :email}`
  then only the html format will use layout, while text will not.
  """
  alias Plug.Conn
  alias Pow.{Config, Phoenix.Mailer.Template, Plug}

  @type t :: %__MODULE__{}

  defstruct [:user, :subject, :text, :html, :assigns]

  @doc """
  Returns a populated `%Pow.Phoenix.Mailer.Mail{}` map.

  If the configuration has `:web_mailer_module`, it will be used to find the
  template module to call.
  """
  @spec new(Conn.t(), map(), {module(), atom()}, Keyword.t()) :: t()
  def new(conn, user, {mail_module, template}, assigns) do
    config       = Plug.fetch_config(conn)
    web_module   = Config.get(config, :web_mailer_module)
    view_assigns = [conn: conn, user: user] |> Keyword.merge(assigns)
    layouts      = conn |> handle_deprecated_layout() |> get_layouts()
    template     = render_mail_template(mail_module, web_module, template, view_assigns, layouts)

    struct(__MODULE__, user: user, subject: template.subject, text: template.text, html: template.html, assigns: assigns)
  end

  # TODO: Remove when MailView structure is hard deprecated
  defp handle_deprecated_layout(conn) do
    case Map.has_key?(conn.private, :pow_mailer_layout) do
      true ->
        IO.warn("`pow_mailer_layout: #{inspect conn.private[:pow_mailer_layout]}` in conn.private has been deprecated, please change it to `pow_mailer_layouts: [_: #{inspect conn.private[:pow_mailer_layout]}]`")

        %{conn | private: Map.put(conn.private, :pow_mailer_layouts, _: conn.private[:pow_mailer_layout])}

      false ->
        conn
    end
  end

  defp get_layouts(conn), do: Map.get(conn.private, :pow_mailer_layouts, _: false)

  defp render_mail_template(module, web_module, template, assigns, layouts) do
    mail_module = replace_web_module(module, web_module)

    case Code.ensure_loaded?(mail_module) do
      true ->
        render(mail_module, template, assigns, layouts)

      # TODO: Remove when MailView structure is hard deprecated
      false ->
        [base, _mail] =
          module
          |> Atom.to_string()
          |> String.split(".Phoenix.")

        module = Module.concat([web_module, base, "MailerView"])

        fallback_render(module, template, assigns, layouts)
    end
  end

  defp replace_web_module(module, nil), do: module
  defp replace_web_module(module, web_module) do
    [base, _mail] =
      module
      |> Atom.to_string()
      |> String.split(".Phoenix.")

    Module.concat([web_module, base <> "Mail"])
  end

  defp render(module, template, assigns, layouts) do
    mail = apply(module, template, [assigns])

    html_layout = get_layout(layouts, :html)
    text_layout = get_layout(layouts, :text)

    html_string =
      mail.html
      |> render_within_layout(assigns, html_layout)
      |> Phoenix.HTML.safe_to_string()

    text_string = render_within_layout(mail.text, assigns, text_layout)

    %{mail |
      html: html_string,
      text: text_string}
  end

  defp get_layout(layouts, format) do
    case layouts do
      layouts when is_list(layouts) -> layouts[format] || layouts[:_] || false
      _layout -> false
    end
  end

  defp render_within_layout(content, _assigns, false), do: content
  defp render_within_layout(content, assigns, {layout_mod, layout_tpl}) do
    apply(layout_mod, layout_tpl, [assigns ++ [inner_content: content]])
  end

  # TODO: Remove when MailView structure is hard deprecated
  defp fallback_render(module, template, assigns, layouts) do
    %Template{
      subject: module.subject(template, assigns),
      text: Phoenix.Template.render_to_string(module, to_string(template), "text", put_layout(assigns, layouts, :text)),
      html: Phoenix.Template.render_to_string(module, to_string(template), "html", put_layout(assigns, layouts, :html))
    }
  end

  def put_layout(assigns, layouts, format) do
    layout = layouts |> get_layout(format) |> parse_layout(format)

    Keyword.put(assigns, :layout, layout)
  end

  defp parse_layout({view, layout}, format) when is_atom(layout), do: {view, "#{layout}.#{format}"}
  defp parse_layout({view, layout}, format) when is_binary(layout) do
    case String.ends_with?(layout, ".#{format}") do
      true  -> {view, layout}
      false -> false
    end
  end
  defp parse_layout(false, _format), do: false
end
