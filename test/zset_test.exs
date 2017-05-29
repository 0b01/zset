defmodule ZSetTest do
  use ExUnit.Case
  doctest ZSet
  import ZSet

  test "it creates an empty set with cardinality 0" do
    assert 0 == new() |> zcard()
  end

  test "it should count zero for a new set within the score range 0..100" do
    assert 0 == new() |> zcount(0, 100)
  end

  test "it should count one for a small set withink the score range 0..100" do
    assert 1 == new() |> zadd(1, "new") |> zcard()
  end

  test "it should be able to initiate with value tuples" do
    zset1 = new([{2, "ab"}])
    zset2 = new() |> zadd(2, "ab")

    assert zset1 == zset2
  end

  test "it should be able to zadd two different items" do
    zset = new()
    |> zadd(2, "ab")
    |> zadd(2, "bc")

    assert 2 == zset |> zcard
    assert 2 == zset |> zcount(0, 100)
  end

  test "it should be sorted byscore then lexicographical order" do
    zset = new()
    |> zadd(2, "ab")
    |> zadd(1, "ab")
    |> zadd(2, "bc")
    |> zadd(1, "bc")

    assert zset |> to_list(:withscores) == [{1, "ab"}, {1, "bc"}]
  end

  test "it should be able to zadd two same items and return the same cardinality" do
    zset = new() |> zadd(1, "new") |> zadd(1, "new")
    assert 1 == zset |> zcard
    assert 1 == zset |> zcount(0, 100)
  end

  test "it should create a node if none exists when incr" do
    zset = new() |> zincrby(1, "new")
    assert 1 == zset |> zcard
    assert 1 == zset |> zcount(0, 100)
  end

  test "it should delete items based on string value" do
    zset = new() |> zadd(1, "new") |> zadd(1, "test")
    zset = zset |> zrem("new")
    assert 1 == zset |> zcard
    assert zset |> to_list(:withscores)
        == new([{1, "test"}]) |> to_list(:withscores)
  end

  test "it should throw an error when deleting non-existent keys" do
    res = new() |> zrem("test")
    {:error, {:non_existent_key, x}} = res
    assert x == "test"
    {:error, {:non_existent_key, xs}} = new() |> zrem(["new", "test"])
    assert xs == ["new", "test"]
  end

  test "it should delete several keys at once" do
    zset = new() |> zadd(1, "new") |> zadd(1, "test")
    assert 0 == zset |> zrem(["new", "test"]) |> zcard
    zset = new() |> zadd(1, "new") |> zadd(1, "test") |> zadd(1, "ok")
    assert [{1,"ok"}]
        == zset |> zrem(["new", "test"]) |> to_list(:withscores)
  end

  test "it knows if an element is in the tree" do
    zset = new() |> zadd(1, "new") |> zadd(1, "test")
    assert zset |> zscore("new") == 1
    assert zset |> zscore("test") == 1
    assert zset |> zscore("blah") == nil
  end

  test "it should add a member when incr if there is none in the zset" do
    zset = new() |> zincrby(1, "new")
    assert 1 == zset |> zscore("new")
    assert ["new"] == zset |> zrange(0, 0)
  end

  test "it should increment member in a set by given score" do
    assert 1 == new() |> zadd(0, "new") |> zincrby(1, "new") |> zscore("new")
  end

  test "it should return the node at index" do
    assert {"b", 1} == tree() |> at(1)
  end

  test "it should return number of keys between a..c" do
    assert 3 == tree() |> zlexcount("a", "c")
  end

  test "zrangebylex" do
    assert ["a", "b", "c"] == tree() |> zrangebylex("[a", "[c")
    assert ["b"] == tree() |> zrangebylex("(a", "(c")
  end

  test "zrevrangebylex" do
    assert ["b", "a"] == tree() |> zrevrangebylex("(c", "[a")
    assert ["c", "b"] == tree() |> zrevrangebylex("[c", "(a")
  end

  test "zrangebyscore" do
    assert ["d"] == tree() |> zrangebyscore("(2", "[3")
    assert ["c"] == tree() |> zrangebyscore("[2", "(3")
  end

  test "zrank" do # This behavior is different
    assert 0 == tree() |> zrank("a")
    assert 1 == tree() |> zrank("b")
  end

  # ZINTERSTORE


  defp tree do
    new()
    |> zadd(0, "a")
    |> zadd(1, "b")
    |> zadd(2, "c")
    |> zadd(3, "d")
    |> zadd(4, "e")
    |> zadd(5, "f")
    |> zadd(0, "g")
  end

end
