defmodule Entice.Web.FriendsController do
  use Entice.Web.Web, :controller
  alias Entice.Web.Queries
  alias Entice.Web.Account

  plug :ensure_login

  @doc "Returns all friends of connected account."
  def index(conn, _params) do
    id = get_session(conn, :client_id)
    {:ok, friends} = Entice.Web.Client.get_friends(id)

    friends = for friend <- friends, do: friend.friend_account.id
    conn |> json ok%{
      message: "All friends",
      friends: friends}
  end

  @doc "Returns a friend's online status and current playing character name."
  def status(conn, _params) do
    account_ids = conn.params["account_id"]
    result = Enum.map(account_ids, fn(x) -> get_single_status(x) end)
    conn |> json result
  end

  defp get_single_status(account_id) do
    result = case Client.get_status(account_id) do
      {:error, :no_matching_account} -> error(%{message: "There is no account with that id."})
      {:ok, status, name} -> ok(%{message: "Friend info retrieval successful.", online_status: status, character_name: name})
    end
    Map.put(%{}, account_id, result)
  end

  @doc "Adds friend :id to friends list of connected account."
  def create(conn, _params) do
    session_id = get_session(conn, :client_id)
    {:ok, acc} = Client.get_account(session_id)
    account_id = acc.id
    friend_account_id = conn.params["friend_account_id"]

    friend_account = Entice.Web.Repo.get(Entice.Web.Account, friend_account_id)

    result = case friend_account do
      nil -> error(%{message: "This account does not exist."})
      %Account{id: ^account_id} -> error(%{message: "Can't add yourself."})
      _ ->
        case Queries.get_friend(account_id, friend_account_id) do
          {:error, :no_matching_friend} ->
            Queries.add_friend(acc, friend_account)
            ok%{message: "Friend added."}
          {:ok, _friend} -> error%{message: "Already in friends list."}
        end
    end
    conn |> json result
  end

  @doc "Deletes friend :id from friends list of connected account."
  def delete(conn, _params) do
    session_id = get_session(conn, :client_id)
    {:ok, acc} = Client.get_account(session_id)
    friend_account_id = conn.params["friend_account_id"]

    result = case Queries.get_friend(acc.id, friend_account_id) do
      {:error, :no_matching_friend} -> error(%{message: "This friend does not exist."})
      {:ok, friend} ->
        Entice.Web.Repo.delete(friend)
        ok(%{message: "Friend deleted."})
    end
    conn |> json result
  end
end
