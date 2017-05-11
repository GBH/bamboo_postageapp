defmodule Bamboo.PostageAppAdapterTest do
  use ExUnit.Case
  import Bamboo.Email

  alias Bamboo.PostageAppAdapter
  alias Bamboo.PostageAppHelper

  @config     %{adapter: PostageAppAdapter, api_key: "API_KEY"}
  @bad_config %{adapter: PostageAppAdapter}

  defmodule FakePostageApp do
    use Plug.Router

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Poison

    plug :match
    plug :dispatch

    def start_server(parent) do
      Agent.start_link(fn -> Map.new end, name: __MODULE__)
      Agent.update(__MODULE__, &Map.put(&1, :parent, parent))
      port = get_free_port()
      Application.put_env(:bamboo, :postageapp_base_uri, "http://localhost:#{port}")
      Plug.Adapters.Cowboy.http __MODULE__, [], port: port, ref: __MODULE__
    end

    defp get_free_port do
      {:ok, socket} = :ranch_tcp.listen(port: 0)
      {:ok, port} = :inet.port(socket)
      :erlang.port_close(socket)
      port
    end

    def shutdown do
      Plug.Adapters.Cowboy.shutdown __MODULE__
    end

    post "/v.1.0/send_message.json" do
      if conn.params["api_key"] do
        response = %{
          response: %{status: "ok", uid: "abc123"},
          data: %{message: %{id: "1234"}}
        }
        conn
        |> send_resp(200, Poison.encode!(response))
        |> send_to_parent

      else
        response = %{
          response: %{status: "bad_request", uid: "abc123", message: "Missing API KEY"}
        }
        conn
        |> send_resp(500, Poison.encode!(response))
        |> send_to_parent
      end
    end

    defp send_to_parent(conn) do
      parent = Agent.get(__MODULE__, fn(set) -> Map.get(set, :parent) end)
      send parent, {:fake_postageapp, conn}
      conn
    end
  end

  setup do
    FakePostageApp.start_server(self())

    on_exit fn ->
      FakePostageApp.shutdown
    end

    :ok
  end

  defp test_email do
    new_email() |> to("to@example.org")
  end

  # -- Tests -------------------------------------------------------------------

  test "handle_config" do
    assert @config == PostageAppAdapter.handle_config(@config)
  end

  test "handle_config with api_key" do
    assert_raise ArgumentError, ~r/no API key set/, fn ->
      PostageAppAdapter.handle_config(%{})
    end
  end

  test "build_api_payload" do
    payload = PostageAppAdapter.build_api_payload(test_email(), @config)
    assert payload == %{
      api_key: "API_KEY",
      arguments: %{
        recipients: "to@example.org"
      }
    }
  end

  test "build_api_key" do
    args = PostageAppAdapter.build_postageapp_arguments(test_email(), @config)
    assert args == %{
      recipients: "to@example.org"
    }
  end

  test "build_api_recipient_override" do
    args = PostageAppAdapter.build_postageapp_arguments(test_email(), @config)
    assert args == %{
      recipients: "to@example.org"
    }

    config = Map.merge(@config, %{recipient_override: "override@example.org"})
    args = PostageAppAdapter.build_postageapp_arguments(test_email(), config)
    assert args == %{
      recipients:         "to@example.org",
      recipient_override: "override@example.org"
    }
  end

  test "build_api_recipients" do
    args = PostageAppAdapter.build_postageapp_arguments(test_email(), @config)
    assert args == %{
      recipients: "to@example.org"
    }
  end

  test "build_api_recipients with tuples" do
    email = new_email() |> to({"User", "to@example.org"})
    args = PostageAppAdapter.build_postageapp_arguments(email, @config)
    assert args == %{
      recipients: "User <to@example.org>"
    }
  end

  test "build_api_recipients with list" do
    email = new_email() |> to([{"User", "to@example.org"}, "other@example.org"])
    args = PostageAppAdapter.build_postageapp_arguments(email, @config)
    assert args == %{
      recipients: ["User <to@example.org>", "other@example.org"]
    }
  end

  test "build_api_recipients with no recipient" do
    assert_raise ArgumentError, ~r/Missing a recipient/, fn ->
      PostageAppAdapter.build_postageapp_arguments(new_email(), @config)
    end
  end

  test "build_api_headers" do
    email = test_email()
      |> subject("Subject")
      |> from({"From", "from@example.org"})
      |> put_header("Reply-To", "reply@example.org")

    args = PostageAppAdapter.build_postageapp_arguments(email, @config)
    assert args == %{
      recipients: "to@example.org",
      headers: %{
        :subject    => "Subject",
        :from       =>  "From <from@example.org>",
        "Reply-To"  => "reply@example.org"
      }
    }
  end

  test "build_api_content" do
    email = test_email()
      |> html_body("HTML")
      |> text_body("Text")

    args = PostageAppAdapter.build_postageapp_arguments(email, @config)
    assert args == %{
      recipients: "to@example.org",
      content: %{
        "text/html"   => "HTML",
        "text/plain"  => "Text"
      }
    }
  end

  # TODO: Bamboo 1.0 will have support for this
  # test "build_api_attachment" do
  #   path = Path.join(__DIR__, "../support/attachment.txt")
  #   email = test_email()
  #     |> put_attachment(path)

  #   raise inspect(email.attachments)
  # end

  test "build_api_template" do
    email = test_email()
      |> PostageAppHelper.postageapp_template("test-template")

    args = PostageAppAdapter.build_postageapp_arguments(email, @config)
    assert args == %{
      recipients: "to@example.org",
      template:   "test-template"
    }
  end

  test "build_api_variables" do
    email = test_email()
      |> PostageAppHelper.postageapp_variables(%{foo: "a", bar: "b"})

    args = PostageAppAdapter.build_postageapp_arguments(email, @config)
    assert args == %{
      recipients: "to@example.org",
      variables:  %{foo: "a", bar: "b"}
    }
  end

  test "deliver" do
    test_email()
    |> from("from@example.org")
    |> subject("test")
    |> text_body("Test")
    |> PostageAppAdapter.deliver(@config)

    assert_receive {:fake_postageapp, %{params: params}}
    assert params == %{
      "api_key"   => "API_KEY",
      "arguments" => %{
        "content" => %{"text/plain" => "Test"},
        "headers" => %{
          "from"    => "from@example.org",
          "subject" => "test"
        },
        "recipients"  => "to@example.org"
      }
    }
  end

  test "deliver failure" do
    assert_raise Bamboo.PostageAppAdapter.ApiError, fn ->
      test_email()
      |> PostageAppAdapter.deliver(@bad_config)
    end
  end
end
