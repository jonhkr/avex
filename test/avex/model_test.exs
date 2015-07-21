defmodule Avex.ModelTest do
  use ExUnit.Case

  defmodule Post do
    use Avex.Model

    defstruct [:a, :b, :c]
    # validate_presence_of [:a, :b]

    update :a, value when is_binary(value) do
      String.upcase(value)
    end
    update :a, nil, do: "nil"

    update :b, [capitalize, capitalize]

    validate :a, my_validation(message: "a must be present")

    validate :b, format(~r/[a-zA-Z]/)

    validate :c, value when is_binary(value) do
      {false, "damn, d value is wrong"}
    end

    validate :c, nil, do: {true, nil}

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

  test "test" do
    {post, valid?, errors} = Post.cast(%{"b" => "asd", "a" => "hey", "c" => "haha"})
    IO.inspect post
    IO.inspect errors
    assert valid? == false
  end
end
