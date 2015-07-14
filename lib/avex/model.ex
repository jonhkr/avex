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

  @doc """
  Register fields of the specified type.

  ## Field types
    * `:required` - The required fields of the model. These fields will be validated as required.
    * `:optional` - Optional fields of the model. Validations will only be applied if the fields are present.

  Any other non registered field will be discarded.
  """
  defmacro fields(field_type, fields)
  defmacro fields(:required, fields) do
    register_fields(:required_fields, fields)
  end
  defmacro fields(:optional, fields) do
    register_fields(:optional_fields, fields)
  end

  defp register_fields(attribute, fields) do
    quote do
      for field <- unquote(fields) do
        Module.put_attribute(__MODULE__, unquote(attribute), field)
      end
    end
  end

  defp scoped_value({:when, _, [value|_]}), do: value
  defp scoped_value({_, _, _} = value), do: quote do: var!(unquote(value))
  defp scoped_value(value), do: value

  defp func_head(call, {:when, context, [_|t]}), do: {:when, context, [call|t]}
  defp func_head(call, _), do: call

  defp quoted_func(call, scope, block) do
    func_head = func_head(call, scope)
    quote do defp unquote(func_head), do: unquote(block) end
  end

  defp register_func({name, field, scope, block}, attribute) do
    scoped_value = scoped_value(scope)
    call = quote do: unquote(name)(unquote(scoped_value), unquote(field))
    quoted_func = quoted_func(call, scope, block)
    quote do
      unquote(quoted_func)
      field = unquote(field)
      attribute = unquote(attribute)
      ref = {field, {unquote(name), [field]}}
      attr = Module.get_attribute(__MODULE__, attribute)
      if not Enum.member?(attr, ref) do
        Module.put_attribute(__MODULE__, attribute, ref)
      end
    end
  end

  @doc """
  Define and register an update function for the specified field.

  ## Examples

      update :field_name, value when is_binary(value) do
        String.upcase(value)
      end
      update :field_name, nil, do: nil
  """
  defmacro update(field, scope, [do: block]) do
    register_func({:update, field, scope, block}, :updates)
  end

  @doc """
  Register an already defined function for the specified field

  ## Example

      defp function_name(value) do
      ...
      end

      update :field_name, with: :function_name

  It is also possible to pass options to the function

  ## Example with function options

      defp function_name(value, opts \\ []) do
      ...
      end

      update :field_name, with: :function_name, opts: [opt1: true]
  """
  defmacro update(field, [{:with, with}|t]) do
    opts = Keyword.get(t, :opts, [])
    if not Keyword.keyword?(opts) do
      raise ArgumentError, message: "invalid opts for #{inspect with}, expected a keyword list, got: #{inspect opts}"
    end

    quote do: @updates {unquote(field), {unquote(with), unquote(opts)}}
  end

  @doc """
  Define and register an validation function for the specified field.

  ## Examples

      validate :field_name, value when is_binary(value), do: :ok

      validate :field_name, value do
        {:error, "value is not binary"}
      end
  """
  defmacro validate(field, scope, [do: block]) do
    register_func({:validate, field, scope, block}, :validations)
  end

  defp put_validation(field, module, ref, opts) do
    quote do
      field = unquote(field)
      module = unquote(module)
      ref = unquote(ref)
      opts = unquote(opts)
      @validations {field, {module, ref, opts}}
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

  defp call(func, value, opts) do
    quote do: unquote(func)(unquote(value), unquote(opts))
  end

  defp apply_updates(field, params, updates) do
    value = quote do: Map.get(params, to_string(unquote(field)))
    field_updates = Keyword.get_values(updates, field)
    Enum.reduce(field_updates, value, fn {func, opts}, value ->
      call(func, value, opts)
    end)
  end

  defp apply_validations(field, value, required_fields, validations) do
    field_validations = Keyword.get_values(validations, field)
    quote do
      field = unquote(field)
      required_fields = unquote(required_fields)
      case unquote(value) do
        nil ->
          if field in required_fields, do: "required", else: []
        value ->
          unquote(field_validations)
          |> Enum.reduce([], fn
            {module, f, opts}, errors ->
              case apply(module, f, [value|opts]) do
                :ok -> errors
                {:error, message} -> [message|errors]
              end
            {f, opts} ->
              case f([value|opts]) do
                :ok -> errors
                {:error, message} -> [message|errors]
              end
          end)
        end
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    required_fields = Module.get_attribute(env.module, :required_fields)
    optional_fields = Module.get_attribute(env.module, :optional_fields)
    fields = required_fields ++ optional_fields

    updates = Enum.reverse(Module.get_attribute(env.module, :updates))
    validations = Enum.reverse(Module.get_attribute(env.module, :validations))

    params = quote do: params

    body = Enum.reduce(fields, {[], []}, fn field, {values, errors} ->
      value = apply_updates(field, params, updates)
      error = apply_validations(field, value, required_fields, validations)
      {[value|values], [error|errors]}
    end)

    IO.puts Macro.to_string(body)

    quote do
      defstruct unquote(fields)

      # def cast(params) do
      #   params = Enum.reduce(params, %{}, fn
      #     {k, v}, acc when is_binary(k) ->
      #       Map.put(acc, k, v)
      #     {k, v}, acc when is_atom(k) ->
      #       Map.put(acc, Atom.to_string(k), v)
      #   end)

      #   {values, errors} = Enum.reduce(fields, {[], []}, fn field, {values, errors} ->
      #     value = Avex.Model.apply_updates(field, Map.get(params, to_string(field)), updates)
      #     {value, error} = Avex.Model.apply_validations(field, value, required_fields, validations)

      #     errors = case error do
      #       {^field, []} -> errors
      #       {^field, _} -> [error|errors]
      #     end

      #     {[value|values], errors}
      #   end)

      #   {struct(__MODULE__, values), length(errors) == 0, errors}
      # end
    end
  end
end