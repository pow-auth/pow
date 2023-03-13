defmodule Pow.Test.Phoenix.PowMail do
  @moduledoc false
  use Pow.Test.Phoenix.Web, :mail

  def test(assigns) do
    %{
      subject: ":web_mailer_module subject #{inspect assigns[:user]}",
      html: ~H"<p>:web_mailer_module html mail <%= inspect @user %></p>",
      text: ~P":web_mailer_module text mail <%= inspect @user %>"
    }
  end
end
