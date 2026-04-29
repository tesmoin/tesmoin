defmodule Tesmoin.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.

  The `Tesmoin.Accounts.Scope` allows public interfaces to receive
  information about the caller, such as if the call is initiated from an
  end-user, and if so, which user. Additionally, such a scope can carry fields
  such as "super user" or other privileges for use as authorization, or to
  ensure specific code paths can only be access for a given scope.

  It is useful for logging as well as for scoping pubsub subscriptions and
  broadcasts when a caller subscribes to an interface or performs a particular
  action.

  Feel free to extend the fields on this struct to fit the needs of
  growing application requirements.
  """

  alias Tesmoin.Accounts.AdminUser

  defstruct admin_user: nil

  @doc """
  Creates a scope for the given admin_user.

  Returns nil if no admin_user is given.
  """
  def for_admin_user(%AdminUser{} = admin_user) do
    %__MODULE__{admin_user: admin_user}
  end

  def for_admin_user(nil), do: nil
end
