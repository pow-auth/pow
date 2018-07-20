defmodule Pow.Phoenix.Mailer.Mail do
  @type t :: %__MODULE__{}

  defstruct [:user, :subject, :text, :html]

  @spec new(map(), binary(), binary(), binary()) :: %__MODULE__{}
  def new(user, text, html, subject) do
    struct(__MODULE__,
      user: user,
      subject: subject,
      text: text,
      html: html)
  end
end
