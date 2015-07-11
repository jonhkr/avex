defmodule Avex.Post do
  use Avex.Model

  fields :required, [:title, :body]
  fields :optional, [:tag]

  update :title, title do
    case title do
      t when is_binary(title) -> String.captalize(title)
      _ -> nil
    end
  end
end