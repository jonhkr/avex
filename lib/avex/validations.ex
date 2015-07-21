defmodule Avex.Validations do

  @number_validators %{
    <:  {&</2,  "must be less than %{count}"},
    >:  {&>/2,  "must be greater than %{count}"},
    <=: {&<=/2, "must be less than or equal to %{count}"},
    >=: {&>=/2, "must be greater than or equal to %{count}"},
    ==: {&==/2, "must be equal to %{count}"},
  }

  def present(value, opts \\ [])
  def present(nil, opts), do: {false, message(opts, "required")}
  def present(value, _opts), do: {true, value}

  def inclusion(value, list, opts \\ []) do
    if value in list do
      {true, value}
    else
      {false, message(opts, "is invalid")}
    end
  end

  def exclusion(value, list, opts \\ []) do
    if value in list do
      {false, message(opts, "is invalid")}
    else
      {true, value}
    end
  end

  def format(value, format, opts \\ []) when is_binary(value) do
    if value =~ format do
      {true, value}
    else
      {false, message(opts, "invalid format")}
    end
  end

  def length(value, opts) when is_binary(value) do
    length = String.length(value)
    error  = ((is = opts[:is]) && wrong_length(length, is, opts)) ||
             ((min = opts[:min]) && too_short(length, min, opts)) ||
             ((max = opts[:max]) && too_long(length, max, opts))
    if error do
      {false, interpolate(error, "%{count}")}
    else
      {true, value}
    end
  end

  defp wrong_length(value, value, _opts), do: nil
  defp wrong_length(_length, value, opts), do:
    {message(opts, "should be %{count} characters"), value}

  defp too_short(length, value, _opts) when length >= value, do: nil
  defp too_short(_length, value, opts), do:
    {message(opts, "should be at least %{count} characters"), value}

  defp too_long(length, value, _opts) when length <= value, do: nil
  defp too_long(_length, value, opts), do:
    {message(opts, "should be at most %{count} characters"), value}

  def number(value, opts) do
    error = ((gt = opts[:>]) && validate_number(value, gt, @number_validators[:>], opts)) ||
            ((lt = opts[:<]) && validate_number(value, lt, @number_validators[:<], opts)) ||
            ((gte = opts[:>=]) && validate_number(value, gte, @number_validators[:>=], opts)) ||
            ((lte = opts[:<=]) && validate_number(value, lte, @number_validators[:<=], opts)) ||
            ((eq = opts[:==]) && validate_number(value, eq, @number_validators[:==], opts))
    if error do
      {false, interpolate(error, "%{count}")}
    else
      {true, value}
    end
  end

  defp validate_number(number, value, op, opts) do
    {func, message} = op
    if not apply(func, number, value) do
      {message(opts, message), value}
    end
  end

  defp interpolate({string, value}, interp) do
    String.replace(string, interp, value)
  end

  defp message(opts, default) do
    opts[:message] || default
  end
end