defmodule Mix.Pow.Phoenix.Mailer do
  @moduledoc """
  Utilities module for mix phoenix mailer tasks.
  """
  alias Mix.Generator

  @doc """
  Creates a mailer view file for the web module.
  """
  @spec create_view_file(atom(), binary(), atom(), binary(), [binary()]) :: :ok
  def create_view_file(module, name, web_mod, web_prefix, mails) do
    subjects = subject_functions(module, name, mails)
    path     = Path.join([web_prefix, "views", Macro.underscore(module), "#{name}_view.ex"])
    content  = """
    defmodule #{inspect(web_mod)}.#{inspect(module)}.#{Macro.camelize(name)}View do
      use #{inspect(web_mod)}, :mailer_view

      #{Enum.join(subjects, "\n")}
    end
    """

    Generator.create_file(path, content)

    :ok
  end

  @doc """
  Creates mailer template files for the web module.
  """
  @spec create_templates(atom(), binary(), binary(), [binary()]) :: :ok
  def create_templates(module, name, web_prefix, mails) do
    template_module = template_module(module, name)
    path            = Path.join([web_prefix, "templates", Macro.underscore(module), name])

    Enum.each(mails, fn mail ->
      for type <- [:html, :text] do
        content   = apply(template_module, type, [mail])
        file_path = Path.join(path, "#{mail}.#{type}.eex")

        Generator.create_file(file_path, content)
      end
    end)
  end

  defp template_module(module, name), do: Module.concat([module, Phoenix, "#{Macro.camelize(name)}Template"])

  defp subject_functions(module, name, mails) do
    template_module = template_module(module, name)

    Enum.map(mails, fn mail ->
      subject = template_module.subject(mail)
      "def subject(#{inspect(mail)}, _assigns), do: #{inspect(subject)}"
    end)
  end
end
