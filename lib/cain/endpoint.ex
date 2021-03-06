defmodule Cain.Endpoint do
  use GenServer
  require Logger

  alias Cain.Endpoint.Error

  @type request :: {:get | :post | :delete, path :: String.t(), query :: map, body :: map}

  @success_codes [200, 204]

  @middleware [Tesla.Middleware.JSON]

  def submit(request) do
    handle_response(GenServer.call(__MODULE__, request))
  end

  def submit_history({method, path, query, body}) do
    {method, "/history" <> path, query, body}
    |> submit()
  end

  def start_link(args \\ []) do
    GenServer.start(__MODULE__, args, name: __MODULE__)
  end

  def init(_args) do
    {:ok, Tesla.client(middleware())}
  end

  def handle_call({:get, path, query, _body}, _from, state) do
    {:reply, Tesla.get(state, path, query: query), state}
  end

  def handle_call({:put, path, query, body}, _from, state) do
    {:reply, Tesla.put(state, path, body, query: Map.to_list(query)), state}
  end

  def handle_call({:post, path, _query, body}, _from, state) do
    {:reply, Tesla.post(state, path, body), state}
  end

  def handle_call({:delete, path, query, _body}, _from, state) do
    {:reply, Tesla.delete(state, path, query: query), state}
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}})
       when status in @success_codes do
    {:ok, body}
  end

  defp handle_response({:ok, %Tesla.Env{status: status, body: body}}) do
    Logger.error("Camunda-REST-API [#{status}] - #{body["type"]}: #{body["message"]}")
    {:error, Error.cast(status, body)}
  end

  defp handle_response({:error, reason}) when is_binary(reason) do
    {:error, Error.cast(nil, %{"type" => "Tesla", "message" => reason})}
  end

  defp handle_response({:error, reason}) do
    handle_response({:error, inspect(reason)})
  end

  defp middleware do
    conf = Application.get_env(:cain, __MODULE__, [])
    url = Keyword.get(conf, :url, nil)
    middleware = Keyword.get(conf, :middleware, [])

    if is_nil(url), do: raise("Incomplete configuration")

    [
      {Tesla.Middleware.BaseUrl, url},
      middleware
      | @middleware
    ]
    |> List.flatten()
  end
end
