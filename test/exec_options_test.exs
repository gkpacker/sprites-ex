defmodule Sprites.ExecOptionsTest do
  use Sprites.Test.ExecCase, async: true

  describe "Sprite.exec_url/4" do
    test "builds the spawn URL with command and default params" do
      assert exec_url("echo", ["hi"], []) ==
               "wss://api.sprites.dev/v1/sprites/my-sprite/exec?stdin=false&path=echo&cmd=echo&cmd=hi"
    end

    test "includes spawn options" do
      query =
        exec_query(
          stdin: true,
          dir: "/app",
          env: [{"FOO", "bar"}],
          tty: true,
          tty_rows: 40,
          tty_cols: 120,
          detachable: true
        )

      assert %{
               "stdin" => "true",
               "dir" => "/app",
               "env" => "FOO=bar",
               "tty" => "true",
               "rows" => "40",
               "cols" => "120",
               "detachable" => "true"
             } = query
    end

    test "builds the attach URL with only stdin/tty params" do
      url = exec_url("bash", [], session_id: "abc", dir: "/app", detachable: true, tty: true)

      assert %URI{path: "/v1/sprites/my-sprite/exec/abc", query: query} = URI.parse(url)
      assert Map.keys(URI.decode_query(query)) |> Enum.sort() == ~w(cols rows stdin tty)
    end
  end

  describe "control-mode exec args" do
    test "include cmd and stdin by default" do
      assert control_op_args("echo", ["hi"], []) == %{"cmd" => ["echo", "hi"], "stdin" => "false"}
    end

    test "include spawn options" do
      opts = [
        stdin: true,
        dir: "/app",
        env: [{"FOO", "bar"}],
        tty: true,
        tty_rows: 40,
        tty_cols: 120
      ]

      assert control_op_args("bash", [], opts) == %{
               "cmd" => ["bash"],
               "dir" => "/app",
               "env" => ["FOO=bar"],
               "tty" => "true",
               "rows" => "40",
               "cols" => "120",
               "stdin" => "true"
             }
    end
  end

  describe "direct-mode exec requests" do
    test "Sprites.spawn/4 connects to the spawn URL with its options" do
      {path, query} =
        direct_request(
          &Sprites.spawn(&1, "bash", ["-l"], dir: "/app", tty: true, detachable: true)
        )

      assert path == "/v1/sprites/SPRITE/exec"

      assert %{
               "cmd" => "-l",
               "path" => "bash",
               "dir" => "/app",
               "tty" => "true",
               "detachable" => "true",
               "stdin" => "false"
             } = query
    end

    test "Sprites.attach_session/3 connects to the attach URL without spawn options" do
      {path, query} = direct_request(&Sprites.attach_session(&1, "abc", dir: "/app", tty: true))

      assert path == "/v1/sprites/SPRITE/exec/abc"
      assert Map.keys(query) |> Enum.sort() == ~w(cols rows stdin tty)
    end

    test "Sprites.cmd/4 returns output and exit code from the exec stream" do
      sprite = fake_sprite(frames: [<<1, "hello">>, <<3, 7>>])

      assert Sprites.cmd(sprite, "echo", ["hello"]) == {"hello", 7}
    end
  end
end
