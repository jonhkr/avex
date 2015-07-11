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

  defp scoped_val({:when, _, [val|_]}), do: val
  defp scoped_val({_, _, _} = val) do
   quote do: var!(unquote(val))
  end
  defp scoped_val(val), do: val

  defp head(call, {:when, context, [_|t]}) do
    {:when, context, [call|t]}
  end
  defp head(call, _), do: call

  defp func(call, scope, block) do
    head = head(call, scope)
    quote do
      def unquote(head), do: unquote(block)
    end
  end

  defp quoted_update_func(field, scope, block) do
    scoped_val = scoped_val(scope)
    call = quote do
      update(unquote(scoped_val), unquote(field))
    end
    func = func(call, scope, block)
    quote do
      unquote(func)
      field = unquote(field)
      @updates {field, {__MODULE__, :update, [field]}}
    end
  end

  defmacro update(field, scope, [do: block]) do
    quoted_update_func(field, scope, block)
  end

  defmacro update(field, [{:with, with}|t]) do
    args = Keyword.get(t, :args, [])
    quote do
      @updates {unquote(field), {__MODULE__, unquote(with), unquote(args)}}
    end
  end

  defmacro validate(field, scoped_val, [do: block]) do
    quote do
      field = unquote(field)
      def validate(var!(unquote(scoped_val)), field), do: unquote(block)
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
      defstruct @required_fields ++ @optional_fields

      def cast(params) do
        required_fields = Enum.reverse @required_fields
        optional_fields = Enum.reverse @optional_fields
        fields = required_fields ++ optional_fields
        updates = Enum.reverse @updates
        validations = Enum.reverse @validations
        params = Avex.normalize(params)

        {values, errors} = Enum.reduce(fields, {[], []}, fn field, {values, errors} ->
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

              errors = case field_errors do
                [] -> errors
                [e] -> [{field, e}|errors]
                el -> [{field, el}|errors]
              end
              {[{field, value}|values], errors}
          end
        end)

        {struct(__MODULE__, values), length(errors) == 0, errors}
      end
    end
  end
end