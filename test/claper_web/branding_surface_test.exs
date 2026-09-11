defmodule ClaperWeb.BrandingSurfaceTest do
  use ClaperWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Claper.PostsFixtures
  import Claper.PresentationsFixtures

  alias Claper.Accounts
  alias Claper.Accounts.UserToken
  alias Claper.Repo

  @brand_logo "/images/claper-logo.png"
  @attribution "Powered by Claper"

  test "account login uses the Claper identity", %{conn: conn} do
    html = conn |> get(~p"/users/log_in") |> html_response(200)

    assert html =~ "Claper"
    assert html =~ @brand_logo
    assert html =~ "claper-auth-backdrop"
    assert html =~ @attribution
    assert title(html) == "Claper"
    refute html =~ " · Claper"
  end

  test "password reset request and edit use the account-access branding", %{conn: conn} do
    request_html = conn |> get(~p"/users/reset_password") |> html_response(200)

    user = user_fixture()
    {token, user_token} = UserToken.build_email_token(user, "reset_password")
    Repo.insert!(user_token)

    edit_html = conn |> get(~p"/users/reset_password/#{token}") |> html_response(200)

    for html <- [request_html, edit_html] do
      assert html =~ "Claper"
      assert html =~ @brand_logo
      assert html =~ "claper-auth-backdrop"
      assert html =~ @attribution
    end
  end

  test "presenter dashboard uses branded chrome and upstream attribution", %{conn: conn} do
    user = confirmed_user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/events")

    assert html =~ "Claper"
    assert html =~ @attribution
    assert title(html) == "Dashboard · Claper"
    refute html =~ " · Claper"
  end

  test "admin chrome identifies Claper Admin and includes attribution", %{conn: conn} do
    ensure_role("user")
    ensure_role("admin")

    user = confirmed_user_fixture()
    {:ok, user} = Accounts.assign_role(user, "admin")

    {:ok, _view, html} = conn |> log_in_user(user) |> live(~p"/admin")

    assert html =~ @attribution
    assert title(html) == "Dashboard · Claper Admin"
    assert html =~ ~s(data-theme="claper")
    refute html =~ ~s(data-theme="light")
    refute html =~ " · Claper Admin"
  end

  test "audience join and presentation content omit upstream attribution", %{conn: conn} do
    {:ok, _join_view, join_html} = live(conn, ~p"/")

    presentation_file = presentation_file_fixture(%{}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    event = presentation_file.event

    {:ok, _event_view, event_html} = live(conn, ~p"/e/#{event.code}")

    for html <- [join_html, event_html] do
      refute html =~ @attribution
      refute html =~ "github.com/ClaperCo/Claper"
      refute html =~ "powered-by"
    end
  end

  test "attendee and presenter chrome use semantic surfaces without changing black media regions",
       %{
         conn: conn
       } do
    presenter = confirmed_user_fixture()
    presentation_file = presentation_file_fixture(%{user: presenter}, [:event])

    presentation_state_fixture(%{
      presentation_file: presentation_file,
      chat_visible: true
    })

    post_fixture(%{
      event: presentation_file.event,
      user: presenter,
      name: "Presenter surface"
    })

    {:ok, _attendee_view, attendee_html} =
      live(conn, ~p"/e/#{presentation_file.event.code}")

    {:ok, _presenter_view, presenter_html} =
      conn
      |> recycle()
      |> log_in_user(presenter)
      |> live(~p"/e/#{presentation_file.event.code}/presenter")

    attendee_document = Floki.parse_document!(attendee_html)
    presenter_document = Floki.parse_document!(presenter_html)

    assert "bg-base-100" in classes(attendee_document, "#side-menu")
    assert "text-base-content" in classes(attendee_document, "#side-menu")
    assert "bg-base-200" in classes(attendee_document, "#side-menu a")
    assert "bg-black" in classes(attendee_document, "#focus-media")
    assert "border-secondary" in classes(attendee_document, "#post-form")

    assert "bg-base-100" in classes(presenter_document, "#post-list > div > div")
    assert "text-base-content" in classes(presenter_document, "#post-list > div > div")
    assert "bg-black" in classes(presenter_document, "#slider-wrapper")
    assert "bg-black" in classes(presenter_document, "#post-list-wrapper")

    app_css = Path.expand("../../assets/css/app.css", __DIR__) |> File.read!()

    [composer_rules] =
      Regex.run(~r/\.attendee-composer\s*\{(.*?)\}/s, app_css, capture: :all_but_first)

    assert composer_rules =~ "var(--color-primary)"
    assert composer_rules =~ "var(--color-secondary)"
    assert composer_rules =~ "80%"
    refute composer_rules =~ "rgba(17, 134, 213"
    refute composer_rules =~ "rgba(163, 39, 255"
  end

  test "attendee explanatory states and pinned presenter cards use contrast-safe colors", %{
    conn: conn
  } do
    presenter = confirmed_user_fixture()

    disabled_file = presentation_file_fixture(%{user: presenter}, [:event])

    presentation_state_fixture(%{
      presentation_file: disabled_file,
      chat_enabled: true,
      anonymous_chat_enabled: false
    })

    {:ok, _disabled_view, disabled_html} = live(conn, ~p"/e/#{disabled_file.event.code}")
    disabled_document = Floki.parse_document!(disabled_html)

    assert "placeholder:text-neutral-100" in classes(disabled_document, "#postFormTA")
    assert "disabled:text-neutral-100" in classes(disabled_document, "#postFormTA")
    refute "disabled:opacity-50" in classes(disabled_document, "#postFormTA")

    chat_off_file = presentation_file_fixture(%{user: presenter}, [:event])

    presentation_state_fixture(%{
      presentation_file: chat_off_file,
      chat_enabled: false
    })

    {:ok, _chat_off_view, chat_off_html} = live(conn, ~p"/e/#{chat_off_file.event.code}")
    chat_off_document = Floki.parse_document!(chat_off_html)

    assert "text-neutral-100" in classes(chat_off_document, "#room-composer .attendee-composer")
    refute "text-white/60" in classes(chat_off_document, "#room-composer .attendee-composer")

    pinned_file = presentation_file_fixture(%{user: presenter}, [:event])

    presentation_state_fixture(%{
      presentation_file: pinned_file,
      chat_visible: true,
      show_only_pinned: true
    })

    post_fixture(%{
      event: pinned_file.event,
      user: presenter,
      name: "Pinned surface",
      pinned: true
    })

    {:ok, _pinned_view, pinned_html} =
      conn
      |> recycle()
      |> log_in_user(presenter)
      |> live(~p"/e/#{pinned_file.event.code}/presenter")

    pinned_document = Floki.parse_document!(pinned_html)
    assert "bg-base-100" in classes(pinned_document, "#pinned-posts > div > div")
    assert "text-base-content" in classes(pinned_document, "#pinned-posts > div > div")
    assert "text-neutral-400" in classes(pinned_document, "#pinned-posts p:first-child")
    assert "bg-black" in classes(pinned_document, "#slider-wrapper")
  end

  test "serves the Apple touch icon referenced by layouts", %{conn: conn} do
    conn = get(conn, "/apple-touch-icon.png")

    assert response(conn, 200) != ""
    assert get_resp_header(conn, "content-type") == ["image/png"]
  end

  test "HTML surfaces reference fingerprinted release assets", %{conn: conn} do
    fingerprints = %{
      "/assets/app.css" => "/assets/app-claper-test.css?vsn=d",
      "/assets/admin.css" => "/assets/admin-claper-test.css?vsn=d",
      "/assets/custom.css" => "/assets/custom-claper-test.css?vsn=d",
      "/assets/app.js" => "/assets/app-claper-test.js?vsn=d"
    }

    Phoenix.Config.clear_cache(ClaperWeb.Endpoint)

    Enum.each(fingerprints, fn {source, fingerprint} ->
      :ets.insert(
        ClaperWeb.Endpoint,
        {{:__phoenix_static__, source}, :cache, {fingerprint, nil}}
      )
    end)

    on_exit(fn -> Phoenix.Config.clear_cache(ClaperWeb.Endpoint) end)

    login_html = conn |> get(~p"/users/log_in") |> html_response(200)
    join_html = conn |> get(~p"/") |> html_response(200)
    not_found_html = Phoenix.View.render_to_string(ClaperWeb.ErrorView, "404.html", %{})
    server_error_html = Phoenix.View.render_to_string(ClaperWeb.ErrorView, "500.html", %{})

    ensure_role("user")
    ensure_role("admin")

    presenter = confirmed_user_fixture()

    {:ok, _view, presenter_html} =
      conn |> recycle() |> log_in_user(presenter) |> live(~p"/events")

    admin = confirmed_user_fixture()
    {:ok, admin} = Accounts.assign_role(admin, "admin")
    {:ok, _view, admin_html} = conn |> recycle() |> log_in_user(admin) |> live(~p"/admin")

    for html <- [
          login_html,
          join_html,
          presenter_html,
          not_found_html,
          server_error_html,
          admin_html
        ] do
      assert html =~ fingerprints["/assets/app.css"]
      assert html =~ fingerprints["/assets/app.js"]
    end

    assert login_html =~ fingerprints["/assets/custom.css"]
    assert join_html =~ fingerprints["/assets/custom.css"]
    assert presenter_html =~ fingerprints["/assets/custom.css"]
    assert not_found_html =~ fingerprints["/assets/custom.css"]
    assert server_error_html =~ fingerprints["/assets/custom.css"]
    assert admin_html =~ fingerprints["/assets/admin.css"]
  end

  test "error surfaces identify the deployed product as Claper" do
    not_found_html = Phoenix.View.render_to_string(ClaperWeb.ErrorView, "404.html", %{})
    server_error_html = Phoenix.View.render_to_string(ClaperWeb.ErrorView, "500.html", %{})
    csrf_error_html = Phoenix.View.render_to_string(ClaperWeb.ErrorView, "csrf_error.html", %{})

    assert title(not_found_html) == "Not found - Claper"
    assert title(server_error_html) == "Not found - Claper"
    assert csrf_error_html =~ "Clear cookies (at least for Claper domain)"

    for html <- [not_found_html, server_error_html, csrf_error_html] do
      refute html =~ "Claper"
    end
  end

  defp title(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("title")
    |> Floki.text()
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end

  defp ensure_role(name) do
    Accounts.get_role_by_name(name) ||
      case Accounts.create_role(%{name: name}) do
        {:ok, role} -> role
        {:error, _changeset} -> Accounts.get_role_by_name(name)
      end
  end
end
