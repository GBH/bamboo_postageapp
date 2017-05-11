defmodule Bamboo.PostageAppAdapter do
  @behaviour Bamboo.Adapter

  @default_base_uri "https://api.postageapp.com"
  @send_email_path  "v.1.0/send_message.json"

  defmodule ApiError do
    defexception [:message]

    def exception(%{message: message}) do
      %ApiError{message: message}
    end

    def exception(%{params: params, response: response}) do
      filtered_params = params |> Poison.decode!

      message = """
      There was a problem sending the email through the PostageApp API.
      Here is the response:
      #{inspect response, limit: :infinity}
      Here are the params we sent:
      #{inspect filtered_params, limit: :infinity}
      """
      %ApiError{message: message}
    end
  end

  def handle_config(config) do
    if config[:api_key] in [nil, ""] do
      raise ArgumentError, """
      There was no API key set for PostageApp adapter.
      * Here are the config options that were passed in:
      #{inspect config}
      """
    else
      config
    end
  end

  def deliver(email, config) do
    uri = [base_uri(), "/", @send_email_path]

    params = email
      |> build_api_payload(config)
      |> Poison.encode!

    case :hackney.post(uri, headers(), params, [:with_body]) do
      {:ok, status, _headers, response} when status > 299 ->
        raise(ApiError, %{params: params, response: response})

      {:ok, status, headers, response} ->
        %{status_code: status, headers: headers, body: response}

      {:error, reason} ->
        raise(ApiError, %{message: inspect(reason)})
    end
  end

  def build_api_payload(email, config) do
    %{}
    |> build_api_key(config)
    |> Map.put(:arguments, build_postageapp_arguments(email, config))
  end

  def build_postageapp_arguments(email, config) do
    %{}
    |> build_api_recipient_override(config)
    |> build_api_recipients(email)
    |> build_api_headers(email)
    |> build_api_content(email)
    # |> build_api_attachments(email)
    |> build_api_template(email)
    |> build_api_variables(email)
  end

  defp build_api_key(payload, config) do
    key = config[:api_key]
    Map.put(payload, :api_key, key)
  end

  defp build_api_recipient_override(payload, config) do
    if config[:recipient_override] in [nil, ""] do
      payload
    else
      Map.put(payload, :recipient_override, config[:recipient_override])
    end
  end

  defp build_api_recipients(payload, email) do
    Map.merge(payload, %{recipients: parse_address(email.to)})
  end

  defp build_api_headers(payload, email) do
    headers = %{}
      |> build_subject(email.subject)
      |> build_from(email.from)
      |> build_headers(email.headers)

    if Enum.empty?(headers) do
      payload
    else
      Map.put(payload, :headers, headers)
    end
  end

  defp build_api_content(payload, email) do
    content = %{}
      |> build_text_body(email.text_body)
      |> build_html_body(email.html_body)

    if Enum.empty?(content) do
      payload
    else
      Map.put(payload, :content, content)
    end
  end

  # TODO: Bamboo 1.0 will have support for this
  # defp build_api_attachments(payload, email) do
  #   payload
  # end

  defp build_api_template(payload, %{private: %{postageapp_template: name}}) do
    Map.put(payload, :template, name)
  end
  defp build_api_template(payload, _), do: payload

  defp build_api_variables(payload, %{private: %{postageapp_variables: variables}}) do
    Map.put(payload, :variables, variables)
  end
  defp build_api_variables(payload, _), do: payload

  defp base_uri do
    Application.get_env(:bamboo, :postageapp_base_uri) || @default_base_uri
  end

  defp headers() do
    [
      {"accept", "application/json"},
      {"content-type", "application/json"}
    ]
  end

  defp parse_address([h | []]),        do: parse_address(h)
  defp parse_address([h | t]),         do: [parse_address(h), parse_address(t)]
  defp parse_address(nil),             do: raise ArgumentError, "Missing a recipient"
  defp parse_address({name, address}), do: "#{name} <#{address}>"
  defp parse_address(address),         do: address

  defp build_subject(headers, ""),      do: headers
  defp build_subject(headers, nil),     do: headers
  defp build_subject(headers, subject), do: Map.put(headers, :subject, subject)

  defp build_from(headers, ""),   do: headers
  defp build_from(headers, nil),  do: headers
  defp build_from(headers, from), do: Map.put(headers, :from, parse_address(from))

  defp build_headers(headers, map) when map == %{}, do: headers
  defp build_headers(headers, map),                 do: Map.merge(headers, map)

  defp build_text_body(content, ""),    do: content
  defp build_text_body(content, nil),   do: content
  defp build_text_body(content, text),  do: Map.put(content, "text/plain", text)

  defp build_html_body(content, ""),    do: content
  defp build_html_body(content, nil),   do: content
  defp build_html_body(content, html),  do: Map.put(content, "text/html", html)
end
