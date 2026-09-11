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
