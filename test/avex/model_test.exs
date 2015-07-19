defmodule Avex.ModelTest do
  use ExUnit.Case

  defmodule Post do
    use Avex.Model

    defstruct [:a, :b, :c]
    # validate_presence_of [:a, :b]

    # update :a, value when is_binary(value) do
    #   String.upcase(value)
    # end
    # update :a, nil, do: nil

    update :b, [capitalize, capitalize]

    validate :a, my_validation(message: "a must be present")

    validate :b, format(~r/[a-zA-Z]/)

    validate :c, value do
      if value do
        {true, value}
      else
        {false, "damn, d value is wrong"}
      end
    end

    defp capitalize(nil), do: nil
    defp capitalize(value) when is_binary(value) do
      String.capitalize(value)
    end

    defp my_validation(value, opts) do
      if value do
        {true, value}
      else
        {false, opts[:message]}
      end
    end
  end
end
