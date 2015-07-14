defmodule Avex.ModelTest do
  use ExUnit.Case

  defmodule Post do
    use Avex.Model

    fields :required, [:title, :body, :number]
    fields :optional, [:tag]

    update :title, title when is_binary(title), do: String.capitalize(title)
    update :title, _, do: nil
    update :body, with: :trim, args: [[max_length: 5]]

    validate :title,
      format: ~r/[a-zA-Z0-9]+/,
      message: "title must be formed of alphanumeric characters"

    validate :tag, inclusion: ["Tech", "Tools", "Movies"]
    validate :tag,
      exclusion: ["Books"],
      message: "should not be \"Books\""

    validate :body, body do
      case String.length(body) do
        len when len < 200 -> {:error, "body is too short"}
        _ -> :ok
      end
    end

    defp trim(data, opts \\ [])
    defp trim(nil, _), do: nil
    defp trim(data, opts) do
      case Keyword.get(opts, :max_length, :infinity) do
        :infinity -> data
        len -> String.slice(data, 0, len)
      end
    end
  end

  test "validate required fields" do
    {_, valid?, errors} = Post.cast(%{})

    assert valid? == false
    assert Keyword.get(errors, :title) == "required"
    assert Keyword.get(errors, :body) == "required"
    assert Keyword.get(errors, :tag) == nil
  end

  test "update fields" do
    {post, _, _} = Post.cast(%{"title" => "capitalized Title"})

    assert post.title == "Capitalized title"
  end

  test "pass args to update function" do
    {post, _, _} = Post.cast(%{"body" => "capitalized Title"})
    assert String.length(post.body) == 5
  end

  test "validate format" do
    {_, _, errors} = Post.cast(%{"title" => "¢$£"})
    assert Keyword.get(errors, :title) == "title must be formed of alphanumeric characters"

    {_, _, errors} = Post.cast(%{"title" => "Alphanumeric t1t1e"})
    assert Keyword.get(errors, :title) == nil
  end

  test "validate included" do
    tag = "Not included"
    {_, _, errors} = Post.cast(%{"tag" => tag})
    assert Keyword.get(errors, :tag) == "#{inspect tag} is invalid"

    {_, _, errors} = Post.cast(%{"tag" => "Tech"})
    assert Keyword.get(errors, :tag) == nil
  end

  test "validate excluded" do
    {_, _, errors} = Post.cast(%{"tag" => "Books"})
    assert "should not be \"Books\"" in Keyword.get(errors, :tag)
  end
end
