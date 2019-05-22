defmodule Pow.Test.Phoenix.Pow.MailerView do
  @moduledoc false
  use Pow.Test.Phoenix.Web, :mailer_view

  def subject(:mail_test, assigns), do: ":web_mailer_module subject #{inspect assigns[:user]} #{inspect assigns[:custom_assign]}"

  def assigns(:mail_test, assigns), do: Keyword.put(assigns, :custom_assign, :custom_assign)
end
