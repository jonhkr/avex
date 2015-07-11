defmodule Avex do

  def validate_format(value, format, opts \\ []) do
    if value =~ format, do: :ok, else: {:error, message(opts, "invalid format")}
  end

  def validate_inclusion(value, data, opts \\ []) do
    if value in data, do: :ok, else: {:error, message(opts, "#{inspect value} is invalid")}
  end

  def validate_exclusion(value, data, opts \\ []) do
    if value in data, do: {:error, message(opts, "#{inspect value} is invalid")}, else: :ok
  end

  def normalize(map) when is_map(map) do
    Enum.reduce(map, %{}, fn 
      {k, v}, acc when is_binary(k) ->
        Map.put(acc, k, v)
      {k, v}, acc when is_atom(k) ->
        Map.put(acc, Atom.to_string(k), v)
    end)
  end

  defp message(opts, default) do
    Keyword.get(opts, :message, default)
  end
end
