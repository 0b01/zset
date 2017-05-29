defmodule ZSet do
  @moduledoc """
    A Red Black Tree implementation that follows the Redis API, complete with scores,
    and with the same big O running time.
  """

  # @behaviour Set

  @type score_tuple :: {integer, String.t}

  @opaque t :: %__MODULE__{
    members: Tree.S,
    size: non_neg_integer
  }

  defstruct members: Tree.new, size: 0


  @spec new(score_tuple) :: t

  def new(tuples \\ []) do
    members = Tree.new
    new_set = %ZSet{
      members: members
    }

    Enum.reduce(tuples, new_set, fn(tuple, zset) ->
      zadd(zset, tuple)
    end)
  end


  @spec zcard(t) :: integer

  def zcard(%ZSet{size: size}) do
    size
  end


  @spec to_list(t, :atom) :: list(score_tuple)

  def to_list(%ZSet{members: members}, opt \\ nil) do
    case opt do
      :withscores ->
        Tree.to_list(members) |> Enum.map(fn {a,b} -> {b,a} end) |> Enum.reverse
      _ ->
        Tree.to_list(members) |> Enum.map(fn {a,_b} -> a end) |> Enum.reverse
    end
  end


  @spec zadd(zset :: t, score :: integer, score_tuple :: String.t) :: t

  def zadd(zset, score, str) when is_integer(score) and is_binary(str) do
    zadd(zset, {score, str})
  end


  @spec zadd(zset :: t, score_tuple) :: t

  defp zadd(%ZSet{members: members}, {score, str}) when is_integer(score) and is_binary(str) do
    tree = Tree.insert(members, str, score)
    {_, new_size} = tree
    %ZSet{members: tree, size: new_size}
  end


  @spec zrem(t, String.t) :: t

  def zrem(%ZSet{}=zset, []), do: zset
  def zrem(%ZSet{size: 0}, k), do: {:error, {:non_existent_key, k}}
  def zrem(%ZSet{members: members}, string) when is_binary(string) do
    tree = Tree.delete members, string
    {new_members, new_size} = tree
    new_size = case new_members do
      nil -> 0
      _ -> new_size
    end
    %ZSet{members: tree, size: new_size}
  end


  @spec zrem(t, list(String.t)) :: t

  def zrem(%ZSet{}=zset, [h|t]) when is_binary(h) do
    zrem (zrem zset, h), t
  end


  @spec zscore(t, String.t) :: integer

  def zscore(%ZSet{members: members}, key) do
    Tree.fetch members, key
  end


  @spec zincrby(t, non_neg_integer(), String.t) :: t

  def zincrby(%ZSet{members: members}=zset, score, key) do
    orig_score = zscore(zset, key)
    orig_score = case orig_score do
      nil -> 0
      _ -> orig_score
    end

    tree = Tree.insert(members, key, orig_score + score)
    {_, new_size} = tree
    %ZSet{members: tree, size: new_size}
  end


  @spec at(t, integer) :: tuple

  def at(%ZSet{members: members}, index) do
    Tree.nth(members, index)
  end


  @spec zcount(t, integer, integer) :: integer

  def zcount(%ZSet{members: tree}, min, max) do
    count = Tree.filter_range_by_value(tree, min, max)
    case count do
      nil -> 0
      a -> a |> Enum.count
    end
  end


  @spec zlexcount(t, String.t, String.t) :: integer

  def zlexcount(%ZSet{members: tree}, min, max) do
    count = Tree.filter_range(tree, min, max)
    case count do
      nil -> 0
      a -> a |> Enum.count
    end
  end


  @spec zrangebylex(t, String.t, String.t) :: integer

  def zrangebylex(%ZSet{members: tree}, min, max, opt \\ nil) do
    min_graphemes = min |> String.graphemes
    max_graphemes = max |> String.graphemes
    {l_inc, l} = case min_graphemes do
      ["[" | rest] -> {true, rest |> Enum.join("")}
      ["(" | rest] -> {false, rest |> Enum.join("")}
      _ -> {true, min_graphemes |> Enum.join("")}
    end
    {r_inc, r} = case max_graphemes do
      ["[" | rest] -> {true, rest |> Enum.join("")}
      ["(" | rest] -> {false, rest |> Enum.join("")}
      _ -> {true, max_graphemes |> Enum.join("")}
    end
    count = Tree.filter_range(tree, l, r, l_inc, r_inc)
    case count do
      nil -> 0
      t ->
        if opt == :withscores do
          t
        else
          t |> Enum.map(fn {a,_b} -> a end)
        end
    end
  end



  @spec zrevrangebylex(t, String.t, String.t) :: integer

  def zrevrangebylex(zset, max, min) do
    zrangebylex(zset, min, max) |> Enum.reverse
  end


  @spec zrange(t, integer, integer, :atom) :: integer

  def zrange(%ZSet{members: tree}, min, max, opt \\ nil) do
    count = Tree.range(tree, min, max)
    case count do
      nil -> 0
      t ->
        if opt == :withscores do
          t
        else
          t |> Enum.map(fn {a,_b} -> a end)
        end
    end
  end

  @spec zrangebyscore(t, integer, integer, :atom) :: term
  def zrangebyscore(%ZSet{members: tree}, min, max, opt \\ nil) do
    min_graphemes = min |> String.graphemes
    max_graphemes = max |> String.graphemes
    {l_inc, l} = case min_graphemes do
      ["[" | rest] -> {true, rest |> Enum.join("")}
      ["(" | rest] -> {false, rest |> Enum.join("")}
      _ -> {true, min_graphemes |> Enum.join("")}
    end
    {r_inc, r} = case max_graphemes do
      ["[" | rest] -> {true, rest |> Enum.join("")}
      ["(" | rest] -> {false, rest |> Enum.join("")}
      _ -> {true, max_graphemes |> Enum.join("")}
    end

    ret = Tree.filter_range_by_value(tree,
                                     String.to_integer(l),
                                     String.to_integer(r),
                                     l_inc,
                                     r_inc)

    if opt == :withscores do
      ret
    else
      ret |> Enum.map(fn {a,_b} -> a end)
    end

  end

  @spec zrank(t, string, :atom) :: term
  def zrank(%ZSet{members: tree}, key, opt \\ nil) do
    Tree.index(tree, key)
  end


end








defimpl Inspect, for: ZSet do
  import Inspect.Algebra

  def inspect(set, opts) do
    concat ["#ZSet<", Inspect.List.inspect(ZSet.to_list(set), opts), ">"]
  end
end
