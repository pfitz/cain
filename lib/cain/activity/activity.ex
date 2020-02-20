defmodule Cain.Activity do
  defmacro __using__(opts) do
    extentional_fields = Keyword.get(opts, :extentional_fields)

    quote do
      def cast(params) do
        struct(__MODULE__, Cain.Response.pre_cast(params))
      end

      def cast(params, extend: :full) do
        params
        |> cast
        |> Cain.Activity.extend_cast(unquote(extentional_fields))
      end

      def cast(params, extend: [only: field]) when is_atom(field) do
        cast(params, extend: [only: [field]])
      end

      def cast(params, extend: [only: fields]) when is_list(fields) do
        filtered = Keyword.take(unquote(extentional_fields), fields)

        params
        |> cast
        |> Cain.Activity.extend_cast(filtered)
      end

      def get_extensional_fields do
        unquote(extentional_fields)
        |> Keyword.keys()
      end
    end
  end

  def extend_cast(activity, extentional_fields) do
    Enum.reduce(extentional_fields, activity, fn {field, func}, activity ->
      Map.put(
        activity,
        field,
        func.(activity.id)
        |> Cain.Endpoint.submit()
        |> case do
          {:ok, response} -> response
          _error -> :error
        end
      )
    end)
  end
end