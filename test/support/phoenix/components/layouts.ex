defmodule Pow.Test.Phoenix.Layouts do
  @moduledoc false
  use Pow.Test.Phoenix.Web, :html

  embed_templates "layouts/*.html"

  embed_templates "layouts/*.text", suffix: "_text"
end
