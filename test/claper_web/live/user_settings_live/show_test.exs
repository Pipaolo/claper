defmodule ClaperWeb.UserSettingsLive.ShowTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Claper.Accounts

  setup :register_and_log_in_user

  test "shows the user's names", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    assert has_element?(view, "p", user.first_name)
    assert has_element?(view, "p", user.last_name)
    assert has_element?(view, "a[href='/users/settings/edit/profile']", "Change")
  end

  test "updates the user's profile", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings/edit/profile")

    view
    |> form("#update_profile", %{
      "user" => %{"first_name" => "Jane", "last_name" => "Smith"}
    })
    |> render_submit()

    assert_redirect(view, ~p"/users/settings")

    updated_user = Accounts.get_user!(user.id)
    assert updated_user.first_name == "Jane"
    assert updated_user.last_name == "Smith"
  end

  test "saves the user's presentation colors", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    view
    |> form("#update_theme", %{
      "user" => %{
        "theme_background" => "#020B43",
        "theme_accent" => "#0473EA",
        "theme_surface" => "#525355"
      }
    })
    |> render_submit()

    assert_redirect(view, ~p"/users/settings")

    assert %{theme_background: "#020B43", theme_accent: "#0473EA", theme_surface: "#525355"} =
             Accounts.get_user!(user.id)
  end

  test "pickers left on the default colors keep the default theme", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    view
    |> form("#update_theme", %{
      "user" => %{
        "theme_background" => "#303a52",
        "theme_accent" => "#0473EA",
        "theme_surface" => "#2b354a"
      }
    })
    |> render_submit()

    assert %{theme_background: nil, theme_accent: "#0473EA", theme_surface: nil} =
             Accounts.get_user!(user.id)
  end

  test "explains why a background is rejected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    html =
      view
      |> form("#update_theme", %{"user" => %{"theme_background" => "#F2F2F2"}})
      |> render_submit()

    assert html =~ "is too light for white text, pick a darker color"
  end

  test "resets the presentation colors to the default theme", %{conn: conn, user: user} do
    {:ok, _user} = Accounts.update_user_theme(user, %{"theme_accent" => "#0473EA"})
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    view |> element("#reset_theme") |> render_click()

    assert_redirect(view, ~p"/users/settings")
    assert %{theme_accent: nil} = Accounts.get_user!(user.id)
  end

  defp upload_logo(view) do
    png = File.read!("priv/static/images/claper-mark.png")

    view
    |> file_input("#update_logo", :logo, [
      %{name: "brand.png", content: png, size: byte_size(png), type: "image/png"}
    ])
    |> render_upload("brand.png")

    view |> form("#update_logo") |> render_submit()
  end

  defp stored_logo_file("/uploads/" <> file),
    do: Path.join([Application.get_env(:claper, :storage_dir), "uploads", file])

  test "uploads a logo that replaces the Claper logo", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")

    upload_logo(view)

    assert_redirect(view, ~p"/users/settings")
    assert %{logo_path: "/uploads/logos/" <> _ = logo_path} = Accounts.get_user!(user.id)
    on_exit(fn -> File.rm(stored_logo_file(logo_path)) end)
    assert File.exists?(stored_logo_file(logo_path))
  end

  test "removes the uploaded logo", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/settings")
    upload_logo(view)
    %{logo_path: logo_path} = Accounts.get_user!(user.id)

    {:ok, view, _html} = live(conn, ~p"/users/settings")
    view |> element("#remove_logo") |> render_click()

    assert_redirect(view, ~p"/users/settings")
    assert %{logo_path: nil} = Accounts.get_user!(user.id)
    refute File.exists?(stored_logo_file(logo_path))
  end

  test "requires both names", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/users/settings/edit/profile")

    html =
      view
      |> form("#update_profile", %{
        "user" => %{"first_name" => "", "last_name" => "Smith"}
      })
      |> render_submit()

    assert html =~ "can&#39;t be blank"
    assert has_element?(view, "#update_profile")
  end
end
