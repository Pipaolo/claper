defmodule ClaperWeb.BrandComponents do
  @moduledoc "Reusable Claper branding components."

  use Phoenix.Component
  use Gettext, backend: ClaperWeb.Gettext

  attr :variant, :atom, values: [:full, :mark], default: :full
  attr :user, :any, default: nil, doc: "shows this user's uploaded logo when they have one"
  attr :class, :any, default: nil

  @doc "Renders a user's uploaded logo, or the Claper logo or compact mark."
  def logo(assigns) do
    assigns =
      case assigns.user do
        %Claper.Accounts.User{logo_path: path} when is_binary(path) ->
          assign(assigns, src: path, alt: gettext("Logo"))

        _no_logo ->
          assign(assigns, src: logo_src(assigns.variant), alt: gettext("Claper"))
      end

    ~H"""
    <img src={@src} alt={@alt} class={@class} />
    """
  end

  attr :class, :any, default: nil

  @doc "Renders a safe attribution link to the upstream Claper project."
  def attribution(assigns) do
    ~H"""
    <a
      href="https://github.com/ClaperCo/Claper"
      target="_blank"
      rel="noopener noreferrer"
      class={@class}
    >
      {gettext("Powered by Claper")}
    </a>
    """
  end

  defp logo_src(:full), do: "/images/claper-logo.png"
  defp logo_src(:mark), do: "/images/claper-mark.png"
end
