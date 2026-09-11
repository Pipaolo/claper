defmodule ClaperWeb.Notifiers.UserNotifierTest do
  use ExUnit.Case, async: false

  alias ClaperWeb.Notifiers.UserNotifier

  test "magic email uses the Claper subject and preserves the configured sender override" do
    previous_mail = Application.get_env(:claper, :mail)

    Application.put_env(:claper, :mail,
      from: "noreply@example.com",
      from_name: "Configured Sender"
    )

    on_exit(fn -> Application.put_env(:claper, :mail, previous_mail) end)

    email = UserNotifier.magic("presenter@example.com", "https://present.example/magic-token")

    assert email.subject == "Connect to Claper"
    assert email.from == {"Configured Sender", "noreply@example.com"}
    assert email.html_body =~ "https://present.example/magic-token"
  end

  test "runtime mail configuration defaults to Claper and honors MAIL_FROM_NAME" do
    previous_config_dir = System.get_env("CONFIG_DIR")
    previous_from_name = System.get_env("MAIL_FROM_NAME")

    System.put_env(
      "CONFIG_DIR",
      Path.join(System.tmp_dir!(), "claper-missing-config-#{System.unique_integer([:positive])}")
    )

    on_exit(fn ->
      restore_env("CONFIG_DIR", previous_config_dir)
      restore_env("MAIL_FROM_NAME", previous_from_name)
    end)

    System.delete_env("MAIL_FROM_NAME")
    default_config = Config.Reader.read!("config/runtime.exs")
    assert default_config[:claper][:mail][:from_name] == "Claper"

    System.put_env("MAIL_FROM_NAME", "Environment Sender")
    override_config = Config.Reader.read!("config/runtime.exs")
    assert override_config[:claper][:mail][:from_name] == "Environment Sender"
  end

  defp restore_env(name, nil), do: System.delete_env(name)
  defp restore_env(name, value), do: System.put_env(name, value)
end
