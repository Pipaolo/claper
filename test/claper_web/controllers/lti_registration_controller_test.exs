defmodule ClaperWeb.Lti.RegistrationControllerTest do
  use ClaperWeb.ConnCase, async: false

  import Lti13.JwksFixtures

  setup :register_and_log_in_user

  setup do
    previous_options = Req.default_options()
    Req.default_options(plug: {Req.Test, __MODULE__})

    on_exit(fn -> Req.default_options(previous_options) end)
  end

  test "registers the exact Claper LMS identity", %{conn: conn} do
    jwk_fixture()
    test_pid = self()

    Req.Test.expect(__MODULE__, 2, fn conn ->
      case conn.request_path do
        "/configuration" ->
          Req.Test.json(conn, %{
            "issuer" => "https://platform.example",
            "registration_endpoint" => "https://platform.example/registration",
            "jwks_uri" => "https://platform.example/jwks",
            "authorization_endpoint" => "https://platform.example/authorize",
            "token_endpoint" => "https://platform.example/token"
          })

        "/registration" ->
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          send(test_pid, {:registration_request, Jason.decode!(body)})

          Req.Test.json(conn, %{
            "client_id" => "claper-client",
            "https://purl.imsglobal.org/spec/lti-tool-configuration" => %{
              "deployment_id" => 42
            }
          })
      end
    end)

    conn =
      post(conn, ~p"/lti/register", %{
        "openid_configuration" => "https://platform.example/configuration",
        "registration_token" => "registration-token"
      })

    assert html_response(conn, 200) =~ "Registration completed"

    assert_receive {:registration_request, registration}
    assert registration["client_name"] == "Claper"

    assert registration["logo_uri"] ==
             "http://localhost:4000/images/claper-logo.png"
  end
end
