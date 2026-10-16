defmodule Sprites.Test.FakeWsServerTest do
  use ExUnit.Case, async: true

  alias Sprites.Test.FakeWsServer

  # Drive the fake server with gun, the same client the SDK uses.
  defp connect(server, path) do
    %URI{port: port} = URI.parse(FakeWsServer.url(server))
    {:ok, conn} = :gun.open(~c"127.0.0.1", port, %{protocols: [:http], transport: :tcp})
    {:ok, _} = :gun.await_up(conn, 1_000)
    stream = :gun.ws_upgrade(conn, path, [])
    assert_receive {:gun_upgrade, ^conn, ^stream, ["websocket"], _}, 1_000
    {conn, stream}
  end

  test "reports the upgrade request path and query to the owner" do
    server = start_supervised!({FakeWsServer, owner: self()})
    connect(server, "/v1/sprites/x/exec?cmd=ls&tty=true")

    assert_receive {:ws_request, "/v1/sprites/x/exec", %{"cmd" => "ls", "tty" => "true"}}
  end

  test "reports unmasked text and binary client frames" do
    server = start_supervised!({FakeWsServer, owner: self()})
    {conn, stream} = connect(server, "/")

    :gun.ws_send(conn, stream, {:text, "control:{}"})
    :gun.ws_send(conn, stream, {:binary, <<0, "stdin">>})
    # longer than 125 bytes exercises the extended length header
    big = String.duplicate("x", 300)
    :gun.ws_send(conn, stream, {:text, big})

    assert_receive {:ws_frame, :text, "control:{}"}
    assert_receive {:ws_frame, :binary, <<0, "stdin">>}
    assert_receive {:ws_frame, :text, ^big}
  end

  test "sends configured binary frames to the client" do
    server = start_supervised!({FakeWsServer, owner: self(), frames: [<<1, "out">>, <<3, 2>>]})
    {conn, stream} = connect(server, "/")

    assert_receive {:gun_ws, ^conn, ^stream, {:binary, <<1, "out">>}}, 1_000
    assert_receive {:gun_ws, ^conn, ^stream, {:binary, <<3, 2>>}}, 1_000
  end
end
