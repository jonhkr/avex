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

  defmacro update(field, scope, [do: block]) do
    scoped_val = scoped_val(scope)
    call = quote do: update(unquote(scoped_val), unquote(field))
    func = func(call, scope, block)
    quote do
      unquote(func)
      field = unquote(field)
      ref = {field, {__MODULE__, :update, [field]}}
      if not Enum.member?(@updates, ref) do
        @updates ref
      end
    end
  end

  defmacro update(field, [{:with, with}|t]) do
    args = Keyword.get(t, :args, [])
    quote do
      @updates {unquote(field), {__MODULE__, unquote(with), unquote(args)}}
    end
  end

  defmacro validate(field, scope, [do: block]) do
    scoped_val = scoped_val(scope)
    call = quote do: validate(unquote(scoped_val), unquote(field))
    func = func(call, scope, block)
    quote do
      unquote(func)
      field = unquote(field)
      ref = {field, {__MODULE__, :validate, [field]}}
      if not Enum.member?(@validations, ref) do
        @validations ref
      end
    end
  end

  defp put_validation(field, module, ref, args) do
    quote do
      field = unquote(field)
      module = unquote(module)
      ref = unquote(ref)
      args = unquote(args)
      @validations {field, {module, ref, args}}
    end
  end

  defmacro validate(field, [{:format, format}|t]) do
    put_validation(field, Avex, :validate_format, [format|[t]])
  end

  defmacro validate(field, [{:inclusion, list}|t]) do
    put_validation(field, Avex, :validate_inclusion, [list|[t]])
  end

  defmacro validate(field, [{:exclusion, list}|t]) do
    put_validation(field, Avex, :validate_exclusion, [list|[t]])
  end

  def normalize(map) when is_map(map) do
    Enum.reduce(map, %{}, fn
      {k, v}, acc when is_binary(k) ->
        Map.put(acc, k, v)
      {k, v}, acc when is_atom(k) ->
        Map.put(acc, Atom.to_string(k), v)
    end)
  end

  def apply_updates(field, value, updates) do
    updates
      |> Keyword.get_values(field)
      |> Enum.reduce(value, fn {m, f, args}, v -> apply(m, f, [v|args]) end)
  end

  defp apply_validation(module, f, args, errors) do
    case apply(module, f, args) do
      :ok -> errors
      {:error, message} -> [message|errors]
    end
  end

  def apply_validations(field, value, required_fields, validations) do
    case value do
      nil ->
        error = if field in required_fields, do: "required", else: []
        {{field, nil}, {field, error}}
      _ ->
        field_errors = validations
          |> Keyword.get_values(field)
          |> Enum.reduce([], fn {m, f, args}, e ->
              apply_validation(m, f, [value|args], e)
            end)

        errors = case field_errors do
          [e] -> {field, e}
          _ -> {field, field_errors}
        end

        {{field, value}, errors}
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
        params = Avex.Model.normalize(params)

        {values, errors} = Enum.reduce(fields, {[], []}, fn field, {values, errors} ->
          value = Avex.Model.apply_updates(field, Map.get(params, to_string(field)), updates)
          {value, error} = Avex.Model.apply_validations(field, value, required_fields, validations)

          errors = case error do
            {^field, []} -> errors
            {^field, _} -> [error|errors]
          end

          {[value|values], errors}
        end)

        {struct(__MODULE__, values), length(errors) == 0, errors}
      end
    end
  end
end