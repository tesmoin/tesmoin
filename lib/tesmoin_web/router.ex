defmodule TesmoinWeb.Router do
  use TesmoinWeb, :router

  import TesmoinWeb.AdminUserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug TesmoinWeb.Plugs.RealIP
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TesmoinWeb.Layouts, :root}
    plug :protect_from_forgery

    # Deliberate trade-off: LiveView currently depends on inline script behavior,
    # so we keep 'unsafe-inline' for scripts. If the framework no longer requires
    # it, tighten this CSP directive.
    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; " <>
          "script-src 'self' 'unsafe-inline'; " <>
          "style-src 'self' 'unsafe-inline'; " <>
          "img-src 'self' data:; " <>
          "connect-src 'self' wss: ws:; " <>
          "font-src 'self'; " <>
          "object-src 'none'; " <>
          "base-uri 'self'; " <>
          "frame-ancestors 'none'"
    }

    plug :fetch_current_scope_for_admin_user
    plug :redirect_to_setup_if_needed
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TesmoinWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  # scope "/api", TesmoinWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:tesmoin, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: TesmoinWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", TesmoinWeb do
    pipe_through [:browser, :require_authenticated_admin_user]

    live_session :require_authenticated_admin_user,
      on_mount: [{TesmoinWeb.AdminUserAuth, :require_authenticated}] do
      live "/admin_users/settings", AdminUserLive.Settings, :edit
      live "/admin_users/settings/confirm-email/:token", AdminUserLive.Settings, :confirm_email
    end
  end

  scope "/", TesmoinWeb do
    pipe_through [:browser]

    live_session :current_admin_user,
      on_mount: [{TesmoinWeb.AdminUserAuth, :mount_current_scope}] do
      live "/setup", SetupLive, :new
      live "/admin_users/log-in", AdminUserLive.Login, :new
      live "/admin_users/log-in/:token", AdminUserLive.Confirmation, :new
    end

    post "/admin_users/log-in", AdminUserSessionController, :create
    delete "/admin_users/log-out", AdminUserSessionController, :delete
  end
end
