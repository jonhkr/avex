defmodule Avex.ModelTest do
  use ExUnit.Case

  defmodule Post do
    use Avex.Model

    defstruct [:title, :body, :tag]
    validate_presence_of [:title, :body]

    update :title, nil, do: nil
    update :title, value when is_boolean(value), do: value
    update :title, value when is_binary(value) do
      String.capitalize(value)
    end

    update :body, [capitalize]
    update :tag, capitalize

    defp capitalize(nil), do: nil
    defp capitalize(value) when is_binary(value) do
      String.capitalize(value)
    end

    validate :title, my_validation(message: "CUSTOM VALIDATION")
    validate :title, true, do: {:error, "DO BLOCK VALIDATION"}
    validate :title, value when is_binary(value) do
      {:error, "DO BLOCK VALIDATION WITH GUARD"}
    end

    validate :body, format(~r/^[a-zA-Z]+$/)
    validate :tag, tag when is_binary(tag) do
      String.upcase(tag)
    end
    validate :tag, nil do
      {:error, "required"}
    end


    defp my_validation(value, opts) do
      if value, do: true, else: {:error, opts[:message]}
    end
  end

  test "update arguments" do
    {post, _valid?, _errors} = Post.cast(%{
      "title" => "uncapitalized text",
      "body" => "uncapitalized text",
      "tag" => "uncapitalized"
    })

    assert post.title == String.capitalize("uncapitalized text")
    assert post.body == String.capitalize("uncapitalized text")
    assert post.tag == String.capitalize("uncapitalized")
  end

  test "validate presence" do
    {post, valid?, errors} = Post.cast(%{})

    assert valid? == false
    assert post.title == nil
    assert post.body == nil

    assert Keyword.get(errors, :title) == "required"
    assert Keyword.get(errors, :body) == "required"
  end

  test "do block validation" do
    {post, valid?, errors} = Post.cast(%{"title" => "binary"})

    assert valid? == false
    assert post.title == "Binary"

    assert Keyword.get(errors, :title) == "DO BLOCK VALIDATION WITH GUARD"

    {post, valid?, errors} = Post.cast(%{"title" => true})

    assert valid? == false
    assert post.title == true

    assert Keyword.get(errors, :title) == "DO BLOCK VALIDATION"
  end

  test "custom validation" do
    {post, valid?, errors} = Post.cast(%{"title" => false})

    assert valid? == false
    assert post.title == false

    assert Keyword.get(errors, :title) == "CUSTOM VALIDATION"
  end

  test "build-in validation" do
    {post, valid?, errors} = Post.cast(%{"body" => "123Ax"})

    assert valid? == false
    assert post.body == "123ax"

    assert Keyword.get(errors, :body) == "invalid format"

    {post, valid?, errors} = Post.cast(%{"body" => "abc"})

    assert valid? == false
    assert post.body == "Abc"

    assert Keyword.get(errors, :body) == nil
  end
end
