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

  defp message(opts, default) do
    Keyword.get(opts, :message, default)
  end
end
