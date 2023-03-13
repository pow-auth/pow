defmodule Mix.Pow.Phoenix.Mailer do
  @moduledoc """
  Utilities module for mix phoenix mailer tasks.
  """
  alias Mix.Generator

  @doc """
  Creates a mail template file.
  """
  @spec create_mail_module(atom(), [atom()], atom(), binary()) :: :ok
  def create_mail_module(module, mails, web_module, web_prefix) do
    templates = template_functions(module, mails)
    path      = Path.join([web_prefix, "mails", "#{Macro.underscore(module)}_mail.ex"])

    content =
      """
      defmodule #{inspect(web_module)}.#{inspect(module)}Mail do
        use #{inspect(web_module)}, :mail
      #{templates |> Enum.join("\n") |> indent("  ")}
      end
      """

    Generator.create_file(path, content)

    :ok
  end

  defp template_functions(module, mails) do
    mail_module = mail_module(module)

    Enum.map(mails, fn mail ->
      """
      def #{mail}(assigns) do
        %Pow.Phoenix.Mailer.Template{
          subject: \"#{mail_module.subject(mail)}\",
          html: ~H\"""#{indent(mail_module.html(mail), "      ")}
            ""\",
          text: ~P\"""#{indent(mail_module.text(mail),  "      ")}
            ""\"
        }
      end
      """
    end)
  end

  defp mail_module(module), do: Module.concat([module, Phoenix, "Mail"])

  defp indent(multiline_string, indent) do
    multiline_string
    |> String.trim()
    |> String.split("\n")
    |> Enum.map_join(&"\n#{indent}#{&1}")
  end
end
