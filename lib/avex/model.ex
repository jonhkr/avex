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
 
  defp def_validation(field, scope, block) do
    quote do
      defp validate_field(unquote(scope), unquote(field)), do: unquote(block)
    end
  end
 
  defp put_validation(field, function) do
    quote do
      @validations {unquote(field), unquote(Macro.escape(function))}
    end
  end
 
  defmacro validate_presence_of(fields, opts \\ []) do
    Enum.map(fields, fn field ->
      put_validation(field, quote(do: present(unquote(opts))))
    end)
  end
 
  defmacro validate(field, functions) when is_list(functions) do
    functions
    |> Enum.reverse
    |> Enum.map(fn function ->
        put_validation(field, function)
      end)
  end
  defmacro validate(field, function), do: put_validation(field, function)
  defmacro validate(field, scope, [do: block]) do
    quote do
      unquote(def_validation(field, scope, block))
      unquote(put_validation(field, quote(do: validate_field(unquote(field)))))
    end
  end
  
  defp def_update(field, scope, block) do
    quote do
      defp update_field(unquote(scope), unquote(field)), do: unquote(block)
    end
  end

  defp put_update(field, function) do
    quote do
      @updates {unquote(field), unquote(Macro.escape(function))}
    end
  end

  defmacro update(field, functions) when is_list(functions) do
    functions
    |> Enum.reverse
    |> Enum.map(fn function ->
        put_update(field, function)
      end)
  end
  defmacro update(field, function), do: put_update(field, function)
  defmacro update(field, scope, [do: block]) do
    quote do
      unquote(def_update(field, scope, block))
      unquote(put_update(field, quote(do: update_field(unquote(field)))))
    end
  end

  defp process_validations_for(field, value, validations) do
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
      value = quote do: Map.get(unquote(values), to_string(unquote(field)))
      error = process_validations_for(field, value, Keyword.get_values(validations, field))
      
      quote bind_quoted: [error: error, errors: errors, field: field] do
        if is_nil(error), do: errors, else: [{field, error} | errors]
      end
    end)
  end

  defp apply_updates(fields, updates) do
    fields
    |> Enum.reduce([], fn field, values ->
        value = quote do: Map.get(params, to_string(unquote(field)))
        value = Keyword.get_values(updates, field)
        |> Enum.reduce(value, fn function, value ->
            Macro.pipe(value, function, 0)
          end)
        [{field, value}, values]
      end)
  end

  @doc false
  defmacro __before_compile__(env) do

    updates = Module.get_attribute(env.module, :updates)
    validations = Module.get_attribute(env.module, :validations)
  
    updated_values = apply_updates(Enum.uniq(Keyword.keys(updates)), updates)
    errors = apply_validations(Enum.uniq(Keyword.keys(validations)), validations)
 
    IO.puts Macro.to_string(updated_values)
 
    IO.inspect Module.get_attribute(env.module, :struct)
    quote do
      def cast(params) do
        params = params
        |> Enum.map(fn k, v ->

        end)
        errors = unquote(errors)
        IO.inspect errors
        # {struct(__MODULE__, values), length(errors) == 0, errors}
      end
    end
  end
end