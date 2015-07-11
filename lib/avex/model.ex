defmodule Avex.Model do
  @doc false
  defmacro __using__(_) do
    quote do
      import Avex.Model

      Module.register_attribute(__MODULE__, :optional_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :required_fields, accumulate: true)
      Module.register_attribute(__MODULE__, :updates, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)

      @before_compile Avex.Model
    end
  end

  defp register_fields(attribute, fields) do
    quote do
      for field <- unquote(fields) do
        Module.put_attribute(__MODULE__, unquote(attribute), field)
      end
    end
  end

  defmacro fields(:required, fields) do
    register_fields(:required_fields, fields)
  end

  defmacro fields(:optional, fields) do
    register_fields(:optional_fields, fields)
  end

  defmacro update(field, [do: block]) do
    quote do
      field = unquote(field)
      def update(var!(value), field), do: unquote(block)
      @updates {field, {__MODULE__, :update, [field]}}
    end
  end

  defmacro update(field, [{:with, with}|t]) do
    args = Keyword.get(t, :args, [])
    quote do
      @updates {unquote(field), {__MODULE__, unquote(with), unquote(args)}}
    end
  end

  defmacro validate(field, [do: block]) do
    quote do
      field = unquote(field)
      def validate(var!(value), field), do: unquote(block)
      @validations {field, {__MODULE__, :validate, [field]}}
    end
  end

  defmacro validate(field, [format: format]) do
    quote do
      @validations {unquote(field), {Avex, :validate_format, [unquote(format)]}}
    end
  end

  defmacro validate(field, [included: list]) do
    quote do
      @validations {unquote(field), {Avex, :validate_inclusion, [unquote(list)]}}
    end
  end

  defmacro validate(field, [excluded: list]) do
    quote do
      @validations {unquote(field), {Avex, :validate_exclusion, [unquote(list)]}}
    end
  end

  @doc false
  defmacro __before_compile__(_) do
    quote do
      def cast(params) do
        required_fields = @required_fields |> Enum.reverse
        optional_fields = @optional_fields |> Enum.reverse
        fields = required_fields ++ optional_fields
        updates = @updates |> Enum.reverse
        validations = @validations |> Enum.reverse

        Enum.reduce(fields, {[], []}, fn field, {values, errors} ->
          value = Map.get(params, to_string(field))

          ufns = Keyword.get_values(updates, field)
          value = Enum.reduce(ufns, value, fn {m, f, args}, value ->
            apply(m, f, [value|args])
          end)

          case value do
            nil when field in @required_fields ->
              {[{field, nil}|values], [{field, "required"}|errors]}
            _ -> 
              vfns = Keyword.get_values(validations, field)
              field_errors = Enum.reduce(vfns, [], fn {m, f, args}, e ->
                case apply(m, f, [value|args]) do
                  :ok -> e
                  {:error, message} -> [message|e]
                end
              end)
              {[{field, value}|values], [{field, field_errors}|errors]}
          end
        end)
      end
    end
  end
end