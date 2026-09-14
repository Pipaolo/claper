defmodule ClaperWeb.UserSettingsLive.Show do
  use ClaperWeb, :live_view

  alias Claper.Accounts

  on_mount(ClaperWeb.UserLiveAuth)

  @impl true
  def mount(_params, session, socket) do
    with %{"locale" => locale} <- session do
      Gettext.put_locale(ClaperWeb.Gettext, locale)
    end

    email_changeset = Accounts.User.email_changeset(%Accounts.User{}, %{})
    password_changeset = Accounts.User.password_changeset(%Accounts.User{}, %{})
    profile_changeset = Accounts.change_user_profile(socket.assigns.current_user)

    oidc_accounts =
      Accounts.get_all_oidc_users_by_email(socket.assigns.current_user.email) |> List.wrap()

    lti_accounts =
      Lti13.Users.get_all_users_by_email(socket.assigns.current_user.email) |> List.wrap()

    preferences_changeset =
      Accounts.User.preferences_changeset(
        socket.assigns.current_user,
        set_locale(socket.assigns.current_user)
      )

    {:ok,
     socket
     |> assign(:email_changeset, email_changeset)
     |> assign(:password_changeset, password_changeset)
     |> assign(:profile_changeset, profile_changeset)
     |> assign(:preferences_changeset, preferences_changeset)
     |> assign(:theme_changeset, Accounts.User.theme_changeset(socket.assigns.current_user, %{}))
     |> allow_upload(:logo,
       accept: ~w(.png .jpg .jpeg .webp),
       max_entries: 1,
       max_file_size: 2_000_000
     )
     |> assign(:is_external_user, oidc_accounts != [] or lti_accounts != [])
     |> assign(:oidc_accounts, oidc_accounts)
     |> assign(:lti_accounts, lti_accounts)
     |> assign(
       :allow_unlink_external_provider,
       Application.get_env(:claper, :allow_unlink_external_provider)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit_email, _params) do
    socket
    |> assign(:page_title, gettext("Update your email"))
    |> assign(
      :page_description,
      gettext("Change the email address you want associated with your account.")
    )
  end

  defp apply_action(socket, :edit_profile, _params) do
    socket
    |> assign(:page_title, gettext("Update your profile"))
    |> assign(
      :page_description,
      gettext("Change the first and last name associated with your account.")
    )
  end

  defp apply_action(socket, :edit_password, _params) do
    socket
    |> assign(:page_title, gettext("Update your password"))
    |> assign(
      :page_description,
      gettext("Change the password used to access your account.")
    )
  end

  defp apply_action(socket, :set_password, _params) do
    socket
    |> assign(:page_title, gettext("Set a new password"))
    |> assign(
      :page_description,
      gettext("Set a new password for your account before unlinking it.")
    )
  end

  defp apply_action(socket, :show, _params) do
    socket
    |> assign(:page_title, gettext("Settings"))
  end

  @impl true
  def handle_event(
        "unlink",
        _params,
        socket
      )
      when length(socket.assigns.oidc_accounts) + length(socket.assigns.lti_accounts) == 1 and
             socket.assigns.current_user.is_randomized_password do
    {:noreply, socket |> redirect(to: ~p"/users/settings/set/password")}
  end

  @impl true
  def handle_event(
        "unlink",
        %{"issuer" => issuer} = _params,
        socket
      ) do
    Claper.Accounts.remove_oidc_user(socket.assigns.current_user, issuer)

    {:noreply,
     socket
     |> put_flash(:info, gettext("The account has been unlinked."))
     |> push_navigate(to: ~p"/users/settings")}
  end

  @impl true
  def handle_event(
        "unlink",
        %{"registration_id" => registration_id} = _params,
        socket
      ) do
    Lti13.Users.remove_user(socket.assigns.current_user, registration_id)

    {:noreply,
     socket
     |> put_flash(:info, gettext("The account has been unlinked."))
     |> push_navigate(to: ~p"/users/settings")}
  end

  @impl true
  def handle_event("save", %{"action" => "update_profile", "user" => user_params}, socket) do
    case Accounts.update_user_profile(socket.assigns.current_user, user_params) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:profile_changeset, Accounts.change_user_profile(user))
         |> put_flash(:info, gettext("Your profile has been updated."))
         |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :profile_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("save", %{"action" => "update_email"} = params, socket) do
    %{"user" => user_params} = params

    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("A link to confirm your email change has been sent to the new address.")
         )
         |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("save", %{"action" => "update_password"} = params, socket) do
    %{"user" => user_params} = params
    %{"current_password" => password} = user_params

    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, _applied_user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Your password has been updated.")
         )
         |> push_navigate(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("save", %{"action" => "update_preferences"} = params, socket) do
    locale = params["user"]["locale"]
    available_locales = Gettext.known_locales(ClaperWeb.Gettext)

    if Enum.member?(available_locales, locale) do
      case Accounts.update_user_preferences(socket.assigns.current_user, params["user"]) do
        {:ok, _applied_user} ->
          {:noreply,
           socket
           |> put_flash(
             :info,
             gettext("Your preferences have been updated.")
           )
           |> redirect(to: ~p"/users/settings")}

        {:error, changeset} ->
          {:noreply, assign(socket, :preferences_changeset, changeset)}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("save", %{"action" => "update_theme", "user" => theme_params}, socket) do
    theme_params = ClaperWeb.Theme.blank_defaults(theme_params)

    case Accounts.update_user_theme(socket.assigns.current_user, theme_params) do
      {:ok, _user} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your theme has been updated."))
         |> redirect(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :theme_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("reset_theme", _params, socket) do
    {:ok, _user} =
      Accounts.update_user_theme(socket.assigns.current_user, %{
        theme_background: nil,
        theme_accent: nil,
        theme_surface: nil
      })

    {:noreply,
     socket
     |> put_flash(:info, gettext("Your theme has been reset."))
     |> redirect(to: ~p"/users/settings")}
  end

  @impl true
  def handle_event("validate_logo", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("save_logo", _params, socket) do
    # The session's current_user can be stale, so replace whatever logo the database has.
    user = Accounts.get_user!(socket.assigns.current_user.id)

    stored =
      consume_uploaded_entries(socket, :logo, fn %{path: path}, entry ->
        extension = entry.client_name |> Path.extname() |> String.downcase()
        {:ok, Accounts.store_user_logo(user, path, extension)}
      end)

    case stored do
      [] ->
        {:noreply, socket}

      _stored ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Your logo has been updated."))
         |> redirect(to: ~p"/users/settings")}
    end
  end

  @impl true
  def handle_event("remove_logo", _params, socket) do
    {:ok, _user} =
      socket.assigns.current_user.id |> Accounts.get_user!() |> Accounts.remove_user_logo()

    {:noreply,
     socket
     |> put_flash(:info, gettext("Your logo has been removed."))
     |> redirect(to: ~p"/users/settings")}
  end

  @impl true
  def handle_event("save", %{"action" => "set_password"} = params, socket) do
    %{"user" => user_params} = params

    user = socket.assigns.current_user

    case Accounts.set_user_password(user, user_params) do
      {:ok, _applied_user} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           gettext("Your password has been set, you can now unlink your account.")
         )
         |> redirect(to: ~p"/users/settings")}

      {:error, changeset} ->
        {:noreply, assign(socket, :password_changeset, changeset)}
    end
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  # Pickers start on the default Claper colors when the user hasn't chosen any.
  defp theme_fields do
    defaults = ClaperWeb.Theme.defaults()

    [
      {:theme_background, gettext("Background"), defaults["theme_background"]},
      {:theme_accent, gettext("Highlight"), defaults["theme_accent"]},
      {:theme_surface, gettext("Surface"), defaults["theme_surface"]}
    ]
  end

  defp upload_error_message(:too_large), do: gettext("That file is over 2 MB.")
  defp upload_error_message(:not_accepted), do: gettext("Use a PNG, JPG or WebP image.")
  defp upload_error_message(_error), do: gettext("That upload didn't work, try another file.")

  defp set_locale(user) when is_nil(user.locale) do
    %{"locale" => "en"}
  end

  defp set_locale(user) do
    %{"locale" => user.locale}
  end
end
