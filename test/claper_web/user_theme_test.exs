defmodule ClaperWeb.UserThemeTest do
  use ClaperWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Claper.AccountsFixtures
  import Claper.PresentationsFixtures

  alias Claper.Accounts

  @standard_chartered %{
    "theme_background" => "#020B43",
    "theme_accent" => "#0473EA",
    "theme_surface" => "#525355"
  }

  defp themed_user(colors \\ @standard_chartered) do
    {:ok, user} = Accounts.update_user_theme(confirmed_user_fixture(), colors)
    user
  end

  test "a themed user sees her colors across the app", %{conn: conn} do
    {:ok, _view, html} = conn |> log_in_user(themed_user()) |> live(~p"/events")

    assert html =~ "--color-primary:#0473EA;"
  end

  test "a user without a theme keeps the default colors", %{conn: conn} do
    {:ok, _view, html} = conn |> log_in_user(confirmed_user_fixture()) |> live(~p"/events")

    refute html =~ ":root:root{"
  end

  defp event_owned_by(user) do
    presentation_file = presentation_file_fixture(%{user: user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    presentation_file.event
  end

  test "attendees of a themed user's event see her colors", %{conn: conn} do
    event = event_owned_by(themed_user())

    {:ok, _view, html} = live(conn, ~p"/e/#{event.code}")

    assert html =~ "--color-primary:#0473EA;"
  end

  test "the owner's colors are part of the event page itself, so live navigation from the join page picks them up",
       %{conn: conn} do
    event = event_owned_by(themed_user())

    {:ok, view, _html} = live(conn, ~p"/e/#{event.code}")

    assert render(view) =~ "--color-primary:#0473EA;"
  end

  test "the event manager carries the owner's colors", %{conn: conn} do
    owner = themed_user()
    event = event_owned_by(owner)

    {:ok, view, _html} = conn |> log_in_user(owner) |> live(~p"/e/#{event.code}/manage")

    assert render(view) =~ "--color-primary:#0473EA;"
  end

  test "the public join page keeps the default theme for a themed signed-in user", %{conn: conn} do
    {:ok, _view, html} = conn |> log_in_user(themed_user()) |> live(~p"/")

    refute html =~ ":root:root{"
  end

  test "on an event page the owner's colors win over the viewer's", %{conn: conn} do
    event = event_owned_by(themed_user())
    viewer = themed_user(%{"theme_accent" => "#FC85AE"})

    {:ok, _view, html} = conn |> log_in_user(viewer) |> live(~p"/e/#{event.code}")

    assert html =~ "--color-primary:#0473EA;"
    refute html =~ "--color-primary:#FC85AE;"
  end
end
