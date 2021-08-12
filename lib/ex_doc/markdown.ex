if Code.ensure_loaded?(ExDoc.Markdown.Earmark) do
  # Due to how relative links works in ExDoc, it's necessary for us to use a
  # custom markdown parser to ensure that paths will work in generated docs.
  #
  # Ref: https://github.com/elixir-lang/ex_doc/issues/889

defmodule ExDoc.Pow.Markdown do
  @moduledoc false

  alias ExDoc.Markdown.Earmark

  @behaviour ExDoc.Markdown

  @impl ExDoc.Markdown
  defdelegate available?, to: Earmark

  @impl ExDoc.Markdown
  def to_ast(text, opts) do
    config     = Mix.Project.config()[:docs]
    source_url = config[:source_url] <> "/" <> source_ref_pattern(config[:source_url], config[:source_ref])

    text
    |> convert_relative_docs_url(source_url)
    |> Earmark.to_ast(opts)
  end

  defp source_ref_pattern("https://github.com/" <> _rest, ref), do: "blob/#{ref}"

  @markdown_regex ~r/(\[[\S ]*\]\()([\S]*?)(\.md|\.ex|\.exs)([\S]*?\))/

  defp convert_relative_docs_url(text, source_url) do
    Regex.replace(@markdown_regex, text, fn
      _, arg1, "http" <> path, extension, arg3 -> "#{arg1}http#{path}#{extension}#{arg3}"
      _, arg1, path, ".md", arg3 -> "#{arg1}#{convert_to_docs_html_url(path)}#{arg3}"
      _, arg1, path, extension, arg3 when extension in [".ex", ".exs"] -> "#{arg1}#{convert_to_source_url(path, extension, source_url)}#{arg3}"
    end)
  end

  defp convert_to_docs_html_url("../invitation/README"), do: "pow_invitation.html"
  defp convert_to_docs_html_url("../email_confirmation/README"), do: "pow_email_confirmation.html"
  defp convert_to_docs_html_url(path), do: path <> ".md"

  defp convert_to_source_url("test/" <> path, extension, source_url), do: source_url <> "/test/" <> path <> extension
end
end
