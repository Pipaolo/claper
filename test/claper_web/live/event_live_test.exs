defmodule ClaperWeb.EventLiveTest do
  use ClaperWeb.ConnCase

  import Phoenix.LiveViewTest
  import Claper.{FormsFixtures, PollsFixtures, PostsFixtures, PresentationsFixtures}

  alias ClaperWeb.EventLive.{
    ManageInteractionListComponent,
    ManageablePostComponent
  }

  @update_attrs %{name: "some updated name"}

  defp create_event(params) do
    presentation_file = presentation_file_fixture(%{user: params.user}, [:event])
    presentation_state_fixture(%{presentation_file: presentation_file})
    params |> Map.put(:presentation_file, presentation_file)
  end

  describe "Index" do
    setup [:register_and_log_in_user, :create_event]

    test "lists all events", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _index_live, html} = live(conn, ~p"/events")

      assert html =~ "events"
      assert html =~ presentation_file.event.name
    end

    test "updates event in listing", %{conn: conn, presentation_file: presentation_file} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      {:ok, conn} =
        index_live
        |> form("#event-form", event: @update_attrs)
        |> render_submit()
        |> follow_redirect(conn, ~p"/events")

      assert html_response(conn, 200) =~ "Updated successfully"
      assert html_response(conn, 200) =~ "some updated name"
    end

    test "renders the redesigned create and edit states", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, edit_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      assert has_element?(edit_live, "#event-editor-title", "Edit event")
      assert has_element?(edit_live, "#presentation-heading", "Presentation")
      assert has_element?(edit_live, "#event-details-heading", "Event details")
      assert has_element?(edit_live, ~s(#date-picker input[type="datetime-local"]))

      assert has_element?(
               edit_live,
               ~s(#date-picker input[name="event[started_at]"][type="hidden"])
             )

      assert has_element?(edit_live, "#facilitators-section")
      assert has_element?(edit_live, "#event-danger-zone", "Delete event")
      assert has_element?(edit_live, ~s(button[form="event-form"]), "Save changes")

      {:ok, new_live, _html} = live(conn, ~p"/events/new")

      assert has_element?(new_live, "#event-editor-title", "Create event")
      assert has_element?(new_live, "#presentation-heading", "Presentation")
      assert has_element?(new_live, ~s(label[for]), "Choose file")
      refute has_element?(new_live, "#facilitators-section")
      refute has_element?(new_live, "#event-danger-zone")
      assert has_element?(new_live, ~s(button[form="event-form"]), "Create event")
    end

    test "uses the user's locale for the native date picker", %{user: user} do
      {:ok, %{locale: "fr"} = user} =
        Claper.Accounts.update_user_preferences(user, %{locale: "fr"})

      conn = build_conn() |> log_in_user(user)
      {:ok, new_live, _html} = live(conn, ~p"/events/new")

      assert has_element?(new_live, ~s(#date-picker input[type="datetime-local"][lang="fr"]))
    end

    test "adds and removes an unsaved facilitator", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      assert has_element?(index_live, "#facilitators-empty-state")

      index_live
      |> element(~s(button[phx-click="add-leader"]))
      |> render_click()

      refute has_element?(index_live, "#facilitators-empty-state")

      assert has_element?(
               index_live,
               ~S|#facilitators-section input[type="email"]:not([readonly])|
             )

      index_live
      |> element(~s(button[phx-click="remove-leader"]))
      |> render_click()

      assert has_element?(index_live, "#facilitators-empty-state")
    end

    test "disables save when event details are invalid", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      index_live
      |> form("#event-form", event: %{name: ""})
      |> render_change()

      assert has_element?(index_live, ~s(button[form="event-form"][disabled]))
    end

    test "keeps the upload active and disables save while a presentation is starting", %{
      conn: conn
    } do
      {:ok, new_live, _html} = live(conn, ~p"/events/new")

      new_live
      |> form("#event-form", event: %{name: "New event"})
      |> render_change()

      upload =
        file_input(new_live, "#file-form", :presentation_file, [
          %{
            name: "slides.pdf",
            content: "%PDF-" <> String.duplicate("0", 95),
            type: "application/pdf"
          }
        ])

      assert render_upload(upload, "slides.pdf", 1) =~ "Uploading... 1%"
      assert has_element?(new_live, ~s(#file-form input[type="file"]))
      assert has_element?(new_live, ~s(button[form="event-form"][disabled]))

      assert render_upload(upload, "slides.pdf", 99) =~ "New presentation ready"
      assert has_element?(new_live, ~s|button[form="event-form"]:not([disabled])|)
    end

    test "does not create an event while a presentation upload is pending", %{conn: conn} do
      {:ok, new_live, _html} = live(conn, ~p"/events/new")
      event_count = Claper.Repo.aggregate(Claper.Events.Event, :count)

      new_live
      |> form("#event-form", event: %{name: "New event"})
      |> render_change()

      upload =
        file_input(new_live, "#file-form", :presentation_file, [
          %{name: "slides.pdf", content: "%PDF-1.4", type: "application/pdf"}
        ])

      assert {:ok, _metadata} = preflight_upload(upload)

      html =
        new_live
        |> form("#event-form", event: %{name: "New event"})
        |> render_submit()

      assert html =~ "Uploading... 0%"
      assert Claper.Repo.aggregate(Claper.Events.Event, :count) == event_count
    end

    test "deletes event in listing", %{conn: conn, presentation_file: presentation_file} do
      {:ok, index_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/edit")

      {:ok, conn} =
        index_live
        |> element(~s{a[phx-click="delete"][phx-value-id=#{presentation_file.event.uuid}]})
        |> render_click()
        |> follow_redirect(conn, ~p"/events")

      {:ok, index_live, _html} = live(conn, ~p"/events")

      refute has_element?(index_live, "#event-#{presentation_file.event.id}")
    end
  end

  describe "Show" do
    setup [:register_and_log_in_user, :create_event]

    test "displays event", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _show_live, html} =
        live(conn, ~p"/e/#{presentation_file.event.code}")

      assert html =~ "Be the first to ask a question or share a thought."
      assert html =~ presentation_file.event.name
    end
  end

  describe "Manage" do
    setup [:register_and_log_in_user, :create_event]

    test "uses semantic dark console surfaces without legacy manager chrome", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      manage_path = ~p"/e/#{presentation_file.event.code}/manage"
      {:ok, manage_live, _html} = live(conn, manage_path)

      assert has_element?(manage_live, "#manager.bg-base-200.text-base-content")
      assert has_element?(manage_live, "#manager header.bg-base-100.border-base-300")
      assert has_element?(manage_live, "#manager main.bg-base-100")
      assert has_element?(manage_live, "#manager aside.bg-base-100")

      assert has_element?(
               manage_live,
               "#manager #interaction-drag-list.bg-base-100.border-base-300"
             )

      default_html = render(manage_live)

      {:ok, import_live, _html} =
        live(conn, ~p"/e/#{presentation_file.event.code}/manage/import")

      manager_html = default_html <> render(import_live)

      for legacy_class <- ["#140553", "#f3defa", "bg-white", "bg-blue-500"] do
        refute manager_html =~ legacy_class
      end
    end

    test "uses semantic manager response bubbles without legacy purple", %{
      presentation_file: presentation_file
    } do
      post =
        post_fixture(%{
          event: presentation_file.event,
          body: "Can we review this?",
          pinned: true
        })

      html =
        render_component(ManageablePostComponent,
          id: "semantic-response",
          event: presentation_file.event,
          post: post
        )

      document = Floki.parse_document!(html)

      assert "bg-base-100" in classes(document, ".rounded-br-2xl")
      assert "text-base-content" in classes(document, ".rounded-br-2xl")
      refute html =~ "rgba(134,17,237"
      refute html =~ "#fff"
      refute html =~ "text-gray-"
      refute html =~ "border-gray-"
    end

    test "reveals manager row actions on keyboard focus and names icon buttons", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      post =
        post_fixture(%{
          event: presentation_file.event,
          body: "Please moderate this response",
          attendee_identifier: "manager-action-attendee",
          user_id: nil
        })

      post_document =
        ManageablePostComponent
        |> render_component(
          id: "keyboard-actions-response",
          event: presentation_file.event,
          post: post
        )
        |> Floki.parse_document!()

      assert Floki.find(
               post_document,
               ~s(.group-focus-within\\:opacity-100 button[aria-label="Pin"])
             ) != []

      assert Floki.find(
               post_document,
               ~s(.group-focus-within\\:opacity-100 button[aria-label="Ban"])
             ) != []

      assert Floki.find(
               post_document,
               ~s(.group-focus-within\\:opacity-100 button[aria-label="Delete"])
             ) != []

      form =
        form_fixture(%{
          presentation_file_id: presentation_file.id,
          title: "Accessible feedback"
        })

      {:ok, submission} =
        Claper.Forms.create_form_submit(%{
          form_id: form.id,
          attendee_identifier: "manager-form-attendee",
          response: %{"Feedback" => "Clear"}
        })

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")
      forms_html = render_click(manage_live, "list-tab", %{"tab" => "forms"})
      forms_document = Floki.parse_document!(forms_html)

      assert Floki.find(
               forms_document,
               ~s(#form-list .group-focus-within\\:opacity-100 button[phx-click="delete-form-submit"][phx-value-id="#{submission.id}"][aria-label="Delete"])
             ) != []
    end

    test "gives every manager switch a visible focus indicator and readable disabled label", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      poll_fixture(%{presentation_file_id: presentation_file.id, position: 0, enabled: true})

      {:ok, _setting} = Claper.Settings.set("transcription_enabled", "true")

      {:ok, _transcription_config} =
        Claper.Transcriptions.create_transcription_config(%{
          presentation_file_id: presentation_file.id,
          enabled: false
        })

      {:ok, _manage_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")
      document = Floki.parse_document!(html)

      switches = Floki.find(document, ~s(button[role="switch"]))
      switch_classes = Floki.attribute(switches, "class")

      assert length(switch_classes) >= 8
      assert Enum.all?(switch_classes, &String.contains?(&1, "focus-visible:ring-2"))
      assert Enum.all?(switch_classes, &String.contains?(&1, "focus-visible:ring-secondary"))
      refute Enum.any?(switch_classes, &String.contains?(&1, "focus:outline-none"))

      assert Enum.all?(switches, fn switch ->
               switch |> Floki.attribute("aria-label") |> Enum.any?(&(&1 != ""))
             end)

      interaction_checkboxes =
        Floki.find(document, ~s(#interaction-drag-list input[type="checkbox"]))

      assert length(interaction_checkboxes) == 2

      assert Enum.all?(interaction_checkboxes, fn checkbox ->
               checkbox |> Floki.attribute("aria-label") |> Enum.any?(&(&1 != ""))
             end)

      assert Floki.find(document, ~s(div.opacity-50 button[role="switch"][disabled])) == []
      assert Floki.find(document, ~s(div.text-neutral-400 button[role="switch"][disabled])) != []
    end

    test "keeps disabled manager descriptions readable without opacity", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, _setting} = Claper.Settings.set("transcription_enabled", "true")

      {:ok, transcription_config} =
        Claper.Transcriptions.create_transcription_config(%{
          presentation_file_id: presentation_file.id,
          enabled: false
        })

      popup_document =
        ManageInteractionListComponent
        |> render_component(
          id: "readable-disabled-popup",
          interactions: [],
          event_code: presentation_file.event.code,
          transcription_config: transcription_config,
          transcription_globally_enabled: true
        )
        |> Floki.parse_document!()

      assert Floki.find(popup_document, ~s(div[aria-disabled="true"].opacity-50)) == []
      assert "text-neutral-400" in classes(popup_document, ~s(div[aria-disabled="true"]))

      {:ok, manage_live, _html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

      render_click(manage_live, "toggle-interaction-modal")

      assert has_element?(manage_live, ~s(#option-5 div[aria-disabled="true"].text-neutral-400))
      refute has_element?(manage_live, ~s(#option-5 div[aria-disabled="true"].opacity-50))
    end

    test "prompts to regenerate missing thumbnails and starts regeneration", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      Oban.Testing.with_testing_mode(:manual, fn ->
        {:ok, manage_live, html} = live(conn, ~p"/e/#{presentation_file.event.code}/manage")

        assert html =~ "No thumbnails are available"
        assert html =~ "Regenerate thumbnails"

        manage_live
        |> element(~s{button[phx-click="regenerate-thumbnails"]})
        |> render_click()

        assert render(manage_live) =~ "Thumbnail regeneration started"
      end)
    end
  end

  describe "Stats" do
    setup [:register_and_log_in_user, :create_event]

    test "hides interaction tabs that have no content", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      {:ok, _stats_live, html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      refute html =~ ~s(phx-value-tab="messages")
      refute html =~ ~s(phx-value-tab="polls")
      refute html =~ ~s(phx-value-tab="forms")
      refute html =~ ~s(phx-value-tab="web_content")
      refute html =~ ~s(phx-value-tab="quizzes")
      refute html =~ ~s(phx-value-tab="transcriptions")
    end

    test "displays transcriptions in report", %{conn: conn, presentation_file: presentation_file} do
      {:ok, _transcription} =
        Claper.Transcriptions.create_transcription(%{
          presentation_file_id: presentation_file.id,
          language: "en",
          text: "Welcome to the event"
        })

      {:ok, stats_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      html =
        stats_live
        |> element(~s{button[phx-value-tab="transcriptions"]})
        |> render_click()

      assert html =~ "Transcriptions"
      assert html =~ "Welcome to the event"
      assert html =~ "UTC"
    end

    test "loads more transcriptions in report", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      for index <- 1..26 do
        {:ok, _transcription} =
          Claper.Transcriptions.create_transcription(%{
            presentation_file_id: presentation_file.id,
            language: "en",
            text: "Transcript segment #{index}"
          })
      end

      {:ok, stats_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      html =
        stats_live
        |> element(~s{button[phx-value-tab="transcriptions"]})
        |> render_click()

      assert html =~ "Transcriptions"
      assert html =~ "Transcript segment 1"
      refute html =~ "Transcript segment 26"
      assert html =~ "Load more"

      html =
        stats_live
        |> element(~s{button[phx-click="load_more_transcriptions"]})
        |> render_click()

      assert html =~ "Transcript segment 1"
      assert html =~ "Transcript segment 26"
      refute html =~ "Load more"
    end

    test "displays emoji avatars for form submissions in report", %{
      conn: conn,
      presentation_file: presentation_file
    } do
      form = form_fixture(%{presentation_file_id: presentation_file.id})

      {:ok, _form_submit} =
        Claper.Forms.create_form_submit(%{
          form_id: form.id,
          attendee_identifier: "attendee-1",
          response: %{"Name" => "Ada"}
        })

      {:ok, stats_live, _html} = live(conn, ~p"/events/#{presentation_file.event.uuid}/stats")

      html =
        stats_live
        |> element(~s{button[phx-value-tab="forms"]})
        |> render_click()

      assert html =~ "Ada"
      assert html =~ "avatar avatar-placeholder"
    end
  end

  describe "Join" do
    test "renders the join page", %{conn: conn} do
      {:ok, join_live, html} = live(conn, ~p"/")

      assert html =~ "Join the event"
      assert html =~ "Enter the code shared by the presenter"
      assert html =~ "Are you a presenter?"
      assert html =~ "Start creating"
      assert html =~ "/users/register"
      refute html =~ "Turn your slides into conversations"

      assert has_element?(join_live, "#form")
      assert has_element?(join_live, "#input[placeholder='ABCD1234']")
      assert has_element?(join_live, ".claper-join-page")
      assert has_element?(join_live, "#input.join-code-input")
      assert has_element?(join_live, "#submit.btn-primary")
      assert has_element?(join_live, ~s(#input[maxlength="10"][required][autofocus]))
      assert has_element?(join_live, ~s(#input[class*="uppercase"]))
      assert has_element?(join_live, ~s(#form[action="/join"]))
      refute html =~ "cyan-"
      refute html =~ "rgba(134, 17, 237"

      join_css = Path.expand("../../../assets/css/app.css", __DIR__) |> File.read!()

      assert join_css =~ """
             .claper-join-page .claper-join-menu-overlay button:focus-visible {
               outline: 2px solid #0F1522;
             """
    end

    test "marks the join input invalid and explains a missing event code", %{conn: conn} do
      {:ok, join_live, _html} = live(conn, ~p"/")

      invalid_event_redirect =
        join_live
        |> form("#form", event: %{code: "MISSING999"})
        |> render_submit()

      root_redirect =
        follow_redirect(invalid_event_redirect, conn, ~p"/e/missing999")

      {:ok, redirected_conn} = follow_redirect(root_redirect, conn, ~p"/")
      {:ok, redirected_join_live, _html} = live(redirected_conn)

      assert has_element?(redirected_join_live, ~s(#form[action="/join"]))

      assert has_element?(
               redirected_join_live,
               ~s(#input[aria-invalid="true"][aria-describedby="join-code-error"])
             )

      assert has_element?(
               redirected_join_live,
               ~s(#join-code-error[role="alert"]),
               "Event doesn't exist"
             )

      assert has_element?(
               redirected_join_live,
               ~s(#join-code-error svg[aria-hidden="true"])
             )
    end

    test "localizes the mobile menu controls", %{conn: conn} do
      conn = put_req_header(conn, "accept-language", "fr")
      {:ok, join_live, _html} = live(conn, ~p"/")

      assert has_element?(join_live, ~s(button[aria-label="Ouvrir le menu"]))
      assert has_element?(join_live, ~s(button[aria-label="Fermer le menu"]))
    end
  end

  defp classes(document, selector) do
    document
    |> Floki.attribute(selector, "class")
    |> List.first()
    |> String.split()
  end
end
