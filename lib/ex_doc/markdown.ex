if Code.ensure_loaded?(ExDoc.Markdown.Earmark) do
  # Due to how relative links works in ExDoc, it's necessary for us to use a
  # custom markdown parser to ensure that paths will work in generated docs.
  #
  # Ref: https://github.com/elixir-lang/ex_doc/issues/889

defmodule ExDoc.Pow.Markdown do
  @moduledoc false

  alias ExDoc.Markdown.Earmark

  @behaviour ExDoc.Markdown

  defdelegate assets(arg), to: Earmark
  defdelegate before_closing_head_tag(arg), to: Earmark
  defdelegate before_closing_body_tag(arg), to: Earmark
  defdelegate configure(arg), to: Earmark
  defdelegate available?(), to: Earmark

  def to_html(text, opts) do
    config     = Mix.Project.config()[:docs]
    source_url = config[:source_url] <> "/" <> source_ref_pattern(config[:source_url], config[:source_ref])

    text
    |> convert_relative_docs_url(source_url)
    |> Earmark.to_html(opts)
  end

  defp source_ref_pattern("https://github.com/" <> _rest, ref), do: "blob/#{ref}"

  @markdown_regex ~r/(\[[\S ]*\]\()([\S]*?)(\.md|\.ex|\.exs)([\S]*?\))/

  defp convert_relative_docs_url(text, source_url) do
    Regex.replace(@markdown_regex, text, fn
      _, arg1, "http" <> path, extension, arg3 -> "#{arg1}http#{path}#{extension}#{arg3}"
      _, arg1, path, ".md", arg3 -> "#{arg1}#{convert_to_docs_html_url(path)}.html#{arg3}"
      _, arg1, path, extension, arg3 when extension in [".ex", ".exs"] -> "#{arg1}#{convert_to_source_url(path, extension, source_url)}#{arg3}"
    end)
  end

  defp convert_to_docs_html_url("../README"), do: "README"
  defp convert_to_docs_html_url("../../../README"), do: "README"
  defp convert_to_docs_html_url("../invitation/README"), do: "pow_invitation"
  defp convert_to_docs_html_url("../email_confirmation/README"), do: "pow_email_confirmation"
  defp convert_to_docs_html_url("lib/extensions/reset_password/README"), do: "pow_reset_password"
  defp convert_to_docs_html_url("lib/extensions/email_confirmation/README"), do: "pow_email_confirmation"
  defp convert_to_docs_html_url("lib/extensions/persistent_session/README"), do: "pow_persistent_session"
  defp convert_to_docs_html_url("lib/extensions/invitation/README"), do: "pow_invitation"
  defp convert_to_docs_html_url("guides/" <> guide), do: guide
  defp convert_to_docs_html_url("../../../guides/" <> guide), do: guide
  defp convert_to_docs_html_url("../guides/" <> guide), do: guide
  defp convert_to_docs_html_url(path), do: path

  defp convert_to_source_url("../lib/" <> path, extension, source_url), do: source_url <> "/lib/" <> path <> extension
  defp convert_to_source_url("lib/" <> path, extension, source_url), do: source_url <> "/lib/" <> path <> extension
  defp convert_to_source_url("test/" <> path, extension, source_url), do: source_url <> "/test/" <> path <> extension
end
end
