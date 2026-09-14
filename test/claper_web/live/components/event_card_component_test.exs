defmodule ClaperWeb.EventCardComponentTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{PresentationsFixtures, EventsFixtures}

  @spec create_event(
          Claper.Accounts.User.t(),
          NaiveDateTime.t(),
          NaiveDateTime.t() | nil,
          map()
        ) ::
          Claper.Presentations.PresentationFile.t()
  defp create_event(user, started_at, expired_at \\ nil, presentation_attrs \\ %{}) do
    event = event_fixture(%{user: user, started_at: started_at, expired_at: expired_at})

    presentation_file =
      presentation_attrs
      |> Map.put(:event, event)
      |> presentation_file_fixture([:event])

    presentation_state_fixture(%{presentation_file: presentation_file})
    presentation_file
  end

  defp with_logo(user) do
    {:ok, user} =
      Claper.Accounts.store_user_logo(user, "priv/static/images/claper-mark.png")

    on_exit(fn -> File.rm(Claper.Accounts.logo_file(user.logo_path)) end)
    user
  end

  describe "EventCardComponent" do
    setup [:register_and_log_in_user]

    test "renders incoming for future event", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.add(NaiveDateTime.utc_now(), 7200, :second))
      {:ok, _view, html} = live(conn, "/events")
      assert html =~ "Incoming"
    end

    test "renders live for current event", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.utc_now())
      {:ok, _view, html} = live(conn, "/events")
      assert html =~ "Live"
    end

    test "uses CSS hover state for grid actions", %{conn: conn, user: user} do
      create_event(user, NaiveDateTime.utc_now())
      {:ok, _view, html} = live(conn, "/events")

      assert html =~ "group-hover:translate-y-0"
      assert html =~ "group-focus-within:translate-y-0"
      refute html =~ "showActions"
    end

    test "uses the brand mark when an event has no thumbnail", %{conn: conn, user: user} do
      presentation_file = create_event(user, NaiveDateTime.utc_now(), nil, %{length: 0})
      {:ok, view, _html} = live(conn, "/events")

      card = "#event-#{presentation_file.event.id}-card"

      assert has_element?(
               view,
               ~s(#{card} img[src="/images/claper-mark.png"][alt="Claper"])
             )

      refute has_element?(view, ~s(#{card} img[src="/images/logo.svg"]))
    end

    test "shows the owner's logo when an event has no thumbnail", %{conn: conn, user: user} do
      user = with_logo(user)
      presentation_file = create_event(user, NaiveDateTime.utc_now(), nil, %{length: 0})
      {:ok, view, _html} = live(conn, "/events")

      assert has_element?(
               view,
               ~s(#event-#{presentation_file.event.id}-card img[src="#{user.logo_path}"])
             )
    end

    test "shows the owner's logo while a presentation is processing", %{conn: conn, user: user} do
      user = with_logo(user)
      presentation_file = create_event(user, NaiveDateTime.utc_now(), nil, %{status: "progress"})
      {:ok, view, _html} = live(conn, "/events")

      assert has_element?(
               view,
               ~s(#event-#{presentation_file.event.id}-card img.animate-pulse[src="#{user.logo_path}"])
             )
    end

    test "a shared event shows its owner's logo, not the viewer's", %{conn: conn, user: user} do
      viewer = with_logo(user)
      owner = with_logo(Claper.AccountsFixtures.user_fixture())
      presentation_file = create_event(owner, NaiveDateTime.utc_now(), nil, %{length: 0})
      activity_leader_fixture(%{event: presentation_file.event, user: viewer})

      {:ok, view, _html} = live(conn, "/events")
      render_click(view, "change-tab", %{"tab" => "invited"})

      card = "#event-#{presentation_file.event.id}-card"
      assert has_element?(view, ~s(#{card} img[src="#{owner.logo_path}"]))
      refute has_element?(view, ~s(#{card} img[src="#{viewer.logo_path}"]))
    end

    test "uses the brand mark while a presentation is processing", %{conn: conn, user: user} do
      presentation_file = create_event(user, NaiveDateTime.utc_now(), nil, %{status: "progress"})
      {:ok, view, _html} = live(conn, "/events")

      card = "#event-#{presentation_file.event.id}-card"

      assert has_element?(
               view,
               ~s(#{card} img.animate-pulse[src="/images/claper-mark.png"][alt="Claper"])
             )

      refute has_element?(view, ~s(#{card} img[src="/images/logo.svg"]))
    end

    test "renders finished for expired event", %{conn: conn, user: user} do
      create_event(
        user,
        NaiveDateTime.add(NaiveDateTime.utc_now(), -7200, :second),
        NaiveDateTime.add(NaiveDateTime.utc_now(), -10, :second)
      )

      {:ok, view, _html} = live(conn, "/events")
      # Expired events are shown in the "Done" tab
      html =
        view
        |> element(".lg\\:flex [phx-click='change-tab'][phx-value-tab='expired']")
        |> render_click()

      assert html =~ "Finished"
    end

    test "renders finished for expired event before starting", %{conn: conn, user: user} do
      create_event(
        user,
        NaiveDateTime.add(NaiveDateTime.utc_now(), 7200, :second),
        NaiveDateTime.utc_now()
      )

      {:ok, view, _html} = live(conn, "/events")
      # Expired events are shown in the "Done" tab
      html =
        view
        |> element(".lg\\:flex [phx-click='change-tab'][phx-value-tab='expired']")
        |> render_click()

      assert html =~ "Finished"
    end
  end
end
