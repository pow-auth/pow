defmodule Pow.Test.Phoenix.Pow.MailerView do
  @moduledoc false
  use Pow.Test.Phoenix.Web, :mailer_view

  def subject(:mail_test, assigns), do: ":web_mailer_module subject #{inspect assigns[:user]}"
end
