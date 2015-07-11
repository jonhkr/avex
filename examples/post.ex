defmodule Avex.Post do
  use Avex.Model

  fields :required, [:title, :body]
  fields :optional, [:tag]

  update :title, title when is_binary(title) do
    String.capitalize(title)
  end
  update :title, v, do: nil
end