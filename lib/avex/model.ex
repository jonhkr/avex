defmodule Avex.Model do
  @doc false
  defmacro __using__(_) do
    quote do
      import Avex.Model
      import Avex.Validations

      Module.register_attribute(__MODULE__, :updates, accumulate: true)
      Module.register_attribute(__MODULE__, :validations, accumulate: true)

      @before_compile Avex.Model
    end
  end

  @doc """
  Mark the provided fields as required

  It is also possible to specify a `:message` to be returned
  for every invalid field

  ## Example

      validate_presence_of([:title, :body], message: "required")

  """
  defmacro validate_presence_of(fields, opts \\ []) do
    Enum.map(fields, fn field ->
      put_validation(field, quote(do: present(unquote(opts))))
    end)
  end

  @doc """
  Register a list of functions to validate the field
  """
  defmacro validate(field, functions) when is_list(functions) do
    functions
    |> Enum.reverse
    |> Enum.map(fn function ->
        put_validation(field, function)
      end)
  end

  @doc """
  Register a function to validate the field

  The function can be any of the pre-defined functions or a validation
  function at the module context.

  ## Examples

      validate :field, present(message: "required")

      validate :field, my_validation(message: "hey you")

      def my_validation(value, opts \\ []) do
        if value do
          {true, value}
        else
          {false, Keyword.get(opts, :message) || "my message"}
        end
      end
  """
  defmacro validate(field, function), do: put_validation(field, function)

  @doc """
  Defines and register a new validation function

  ## Examples

      validate :field, value do
        {true, value}
      end

  Guards are also supported

      validate :field, value when is_binary(value) do
        {true, value}
      end

      validate :field, _, do: {false, "invalid"}
  """
  defmacro validate(field, scope, [do: block]) do
    quote do
      unquote(def_validation(field, scope, block))
      unquote(put_validation(field, quote(do: validate_field(unquote(field)))))
    end
  end

  @doc """
  Register a list of functions to update the field
  """
  defmacro update(field, functions) when is_list(functions) do
    functions
    |> Enum.reverse
    |> Enum.map(fn function ->
        put_update(field, function)
      end)
  end

  @doc """
  Register a function to update the field

  The function must be in the module's context
  
  **All update functions are executed before the validations**

  ## Examples

      update :field, capitalize

      def capitalize(value) when is_binary(value) do
        String.capitalize
      end

      def capitalize(nil), do: nil
  """
  defmacro update(field, function), do: put_update(field, function)

  @doc """
  Defines and register an update function

  ## Examples

      update :field, value do
        case Integer.parse(value) do
          {i, _} -> i
          :error -> nil
        end
      end

  Guards are also supported

      update :field, value when is_binary(value) do
        case Integer.parse(value) do
          {i, _} -> i
          :error -> nil
        end
      end

      update :field, value when is_integer(value), do: value
      update :field, _, do: nil
  """
  defmacro update(field, scope, [do: block]) do
    quote do
      unquote(def_update(field, scope, block))
      unquote(put_update(field, quote(do: update_field(unquote(field)))))
    end
  end

  # Private

  defp validate_field(field) do
    quote bind_quoted: [field: field] do
      unless Map.has_key?(@struct, field) do
        raise ArgumentError, message: "field #{inspect field} is not registered, " <>
          "make sure it is in the struct definition."
      end
    end
  end

  defp scoped_value({:when, _, [value|_]}), do: value
  defp scoped_value(value), do: value

  defp func_head(call, {:when, context, [_|t]}), do: {:when, context, [call|t]}
  defp func_head(call, _), do: call

  defp def_validation(field, scope, block) do
    call = quote do: validate_field(unquote(scoped_value(scope)), unquote(field))
    quote do
      unquote validate_field(field)
      defp unquote(func_head(call, scope)), do: unquote(block)
    end
  end

  defp put_validation(field, function) do
    quote do
      unquote validate_field(field)
      field = unquote(field)
      function = unquote(Macro.escape(function))
      ref = {field, function}
      if not Enum.member?(@validations, ref), do: @validations ref
    end
  end

  defp def_update(field, scope, block) do
    call = quote do: update_field(unquote(scoped_value(scope)), unquote(field))
    quote do
      unquote validate_field(field)
      defp unquote(func_head(call, scope)), do: unquote(block)
    end
  end

  defp put_update(field, function) do
    quote do
      unquote validate_field(field)
      field = unquote(field)
      function = unquote(Macro.escape(function))
      ref = {field, function}
      if not Enum.member?(@updates, ref), do: @updates ref
    end
  end

  defp get_fields(env), do: Module.get_attribute(env.module, :struct)
  defp get_validations(env), do: Module.get_attribute(env.module, :validations)
  defp get_updates(env), do: Module.get_attribute(env.module, :updates)

  defp process_field_validations(value, validations) do
    validations
    |> Enum.reduce(nil, fn function, errors ->
      validation = Macro.pipe(value, function, 0)

      quote do
        case unquote(validation) do
          {true, _} -> unquote(errors)
          {false, message} -> message
        end
      end
    end)
  end

  defp apply_validations(fields, validations) do
    values = quote do: values
    fields
    |> Enum.reduce([], fn field, errors ->
      value = quote do: Keyword.get(unquote(values), unquote(field))
      field_validations = Keyword.get_values(validations, field)

      quote do
        case unquote(process_field_validations(value, field_validations)) do
          nil -> unquote(errors)
          error ->[{unquote(field), error} | unquote(errors)]
        end
      end
    end)
  end

  defp apply_updates(fields, updates) do
    fields
    |> Enum.reduce([], fn {field, value}, values ->
        value = quote do: Map.get(params, to_string(unquote(field)), unquote(value))
        value = Keyword.get_values(updates, field)
        |> Enum.reduce(value, fn function, value ->
            Macro.pipe(value, function, 0)
          end)

        [{field, value} | values]
      end)
  end

  @doc false
  defmacro __before_compile__(env) do
    updates = get_updates(env)
    validations = get_validations(env)
    fields = get_fields(env)
    |> Map.delete(:__struct__)

    values = apply_updates(fields, updates)
    errors = apply_validations(Enum.uniq(Keyword.keys(validations)), validations)

    quote do
      def cast(params) do
        params = params
        |> Enum.reduce(%{}, fn {key, value}, map ->
          case key do
            k when is_atom(k) ->
              Map.put(map, Atom.to_string(k), value)
            k when is_binary(k) ->
              Map.put(map, k, value)
            _ -> raise ArgumentError, message: "unespected key: #{inspect key}"
          end
        end)

        values = unquote(values)
        errors = unquote(errors)

        {struct(__MODULE__, values), length(errors) == 0, errors}
      end
    end
  end
end