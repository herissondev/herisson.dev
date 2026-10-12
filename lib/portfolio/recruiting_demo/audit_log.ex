defmodule Portfolio.RecruitingDemo.AuditLog do
  @moduledoc """
  Append-only, hash-chained journal of every pipeline fact.

  Appends go through this single process: the ETS data layer has no
  transactions and research steps run concurrently, so serialising here is
  what keeps `seq` and `prev_hash` consistent.

  Only two places call `append/1`: Ash changes on business actions and the
  Reactor middleware (orchestration events).
  """
  use GenServer

  require Ash.Query

  alias Portfolio.RecruitingDemo.Actor
  alias Portfolio.RecruitingDemo.Resources.AuditEvent

  @genesis String.duplicate("0", 64)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Appends an event. `attrs` needs `:application_id`, `:actor` (an `Actor`),
  `:type` and `:payload`.
  """
  def append(%{actor: %Actor{}} = attrs), do: GenServer.call(__MODULE__, {:append, attrs})

  @doc "Events of an application, in `seq` order, as seen by `actor`."
  def events(application_id, actor) do
    AuditEvent
    |> Ash.Query.filter(application_id == ^application_id)
    |> Ash.Query.sort(seq: :asc)
    |> Ash.read!(actor: actor)
  end

  @doc """
  Recomputes the chain. Returns `:ok` or `{:error, seq}` for the first event
  whose hash or link does not match.
  """
  def verify(events) do
    Enum.reduce_while(events, @genesis, fn event, prev_hash ->
      if event.prev_hash == prev_hash and event.hash == hash(prev_hash, event) do
        {:cont, event.hash}
      else
        {:halt, {:error, event.seq}}
      end
    end)
    |> case do
      {:error, _} = error -> error
      _last_hash -> :ok
    end
  end

  @doc "Canonical form: fixed field order, sorted keys, ISO timestamps."
  def canonical(event) do
    [
      event.session_id,
      event.application_id,
      event.seq,
      DateTime.to_iso8601(event.at),
      event.actor_kind,
      event.actor_role,
      event.type,
      event.payload
    ]
    |> sort_keys()
    |> Jason.encode!()
  end

  def hash(prev_hash, event),
    do: :crypto.hash(:sha256, prev_hash <> canonical(event)) |> Base.encode16(case: :lower)

  @impl true
  def init(_opts), do: {:ok, nil}

  @impl true
  def handle_call({:append, attrs}, _from, state) do
    {:reply, do_append(attrs), state}
  end

  defp do_append(%{actor: actor} = attrs) do
    {seq, prev_hash} = last_link(attrs.application_id)

    event = %{
      session_id: actor.session_id,
      application_id: attrs.application_id,
      seq: seq,
      at: DateTime.utc_now(),
      actor_kind: Atom.to_string(actor.kind),
      actor_role: Atom.to_string(actor.role),
      type: Atom.to_string(attrs.type),
      # Stored in its JSON form so that re-hashing reads back exactly what was hashed
      payload: attrs.payload |> Jason.encode!() |> Jason.decode!()
    }

    AuditEvent
    |> Ash.Changeset.for_create(
      :append,
      Map.merge(event, %{prev_hash: prev_hash, hash: hash(prev_hash, event)}),
      actor: actor,
      context: %{audit_log?: true}
    )
    |> Ash.create()
  end

  defp last_link(application_id) do
    AuditEvent
    |> Ash.Query.filter(application_id == ^application_id)
    |> Ash.Query.sort(seq: :desc)
    |> Ash.Query.limit(1)
    |> Ash.read!(authorize?: false)
    |> case do
      [last] -> {last.seq + 1, last.hash}
      [] -> {1, @genesis}
    end
  end

  defp sort_keys(map) when is_map(map) and not is_struct(map) do
    map
    |> Enum.map(fn {k, v} -> {to_string(k), sort_keys(v)} end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Jason.OrderedObject.new()
  end

  defp sort_keys(list) when is_list(list), do: Enum.map(list, &sort_keys/1)
  defp sort_keys(other), do: other
end
