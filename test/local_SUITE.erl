-module(local_SUITE).

-include_lib("common_test/include/ct.hrl").

%% Common Test
-export([
  all/0,
  init_per_suite/1,
  end_per_suite/1,
  init_per_testcase/2,
  end_per_testcase/2
]).

%% Tests
-export([
  t_basic_ops/1,
  t_match_ops/1,
  t_select_ops/1,
  t_paginated_ops/1,
  t_first_last_next_prev_ops/1,
  t_update_ops/1,
  t_fold_ops/1,
  t_info_ops/1
]).

-include_lib("stdlib/include/ms_transform.hrl").

-define(DUPLICATE_BAG, test_duplicate_bag).
-define(ETS_DUPLICATE_BAG, ets_test_duplicate_bag).
-define(SET, test_set).
-define(ETS_SET, ets_test_set).
-define(ORDERED_SET, test_ordered_set).
-define(ETS_ORDERED_SET, ets_test_ordered_set).
-define(SHARDS_TABS, [?SET, ?DUPLICATE_BAG, ?ORDERED_SET]).
-define(ETS_TABS, [?ETS_SET, ?ETS_DUPLICATE_BAG, ?ETS_ORDERED_SET]).

%%%===================================================================
%%% Common Test
%%%===================================================================

all() -> [
  t_basic_ops,
  t_match_ops,
  t_select_ops,
  t_paginated_ops,
  t_first_last_next_prev_ops,
  t_update_ops,
  t_fold_ops,
  t_info_ops
].

init_per_suite(Config) ->
  shards:start(),
  Config.

end_per_suite(Config) ->
  shards:stop(),
  Config.

init_per_testcase(_, Config) ->
  init_shards(),
  Config.

end_per_testcase(_, Config) ->
  delete_shards_pool(),
  Config.

%%%===================================================================
%%% Exported Tests Functions
%%%===================================================================

t_basic_ops(_Config) ->
  true = cleanup_shards(),

  % insert some K/V pairs
  Obj1 = {kx, 1, a, "hi"},
  KVPairs = [
    {k1, 1}, {k1, 2}, {k1, 1},
    {k2, 2},
    {k11, 11},
    {k22, 22},
    Obj1
  ],
  7 = length(shards:insert(?DUPLICATE_BAG, KVPairs)),
  true = shards:insert(?DUPLICATE_BAG, Obj1),
  true = ets:insert(?ETS_DUPLICATE_BAG, KVPairs),
  true = ets:insert(?ETS_DUPLICATE_BAG, Obj1),

  % insert new
  false = ets:insert_new(?ETS_DUPLICATE_BAG, [Obj1, {k3, <<"V3">>}]),
  [false, true] = shards:insert_new(?DUPLICATE_BAG, [Obj1, {k3, <<"V3">>}]),
  true = ets:insert_new(?ETS_DUPLICATE_BAG, {k3, <<"V3">>}),
  false = shards:insert_new(?DUPLICATE_BAG, {k3, <<"V3">>}),

  % select and match
  R1 = lists:usort(ets:select(?ETS_DUPLICATE_BAG, [{{'$1', '$2'}, [], ['$$']}])),
  R1 = lists:usort(shards:select(?DUPLICATE_BAG, [{{'$1', '$2'}, [], ['$$']}])),
  R2 = lists:usort(ets:match(?ETS_DUPLICATE_BAG, '$1')),
  R2 = lists:usort(shards:match(?DUPLICATE_BAG, '$1')),

  % lookup
  R3 = ets:lookup_element(?ETS_DUPLICATE_BAG, k1, 2),
  R3 = shards:lookup_element(?DUPLICATE_BAG, k1, 2),
  R4 = lookup_keys(ets, ?ETS_DUPLICATE_BAG, [k1, k2, k3, kx]),
  R4 = lookup_keys(shards, ?DUPLICATE_BAG, [k1, k2, k3, kx]),

  % delete
  true = ets:delete_object(?ETS_DUPLICATE_BAG, Obj1),
  true = ets:delete(?ETS_DUPLICATE_BAG, k2),
  true = shards:delete_object(?DUPLICATE_BAG, Obj1),
  true = shards:delete(?DUPLICATE_BAG, k2),
  [] = lookup_keys(ets, ?ETS_DUPLICATE_BAG, [k1, k2, kx]),
  [] = lookup_keys(shards, ?DUPLICATE_BAG, [k1, k2, kx]),

  % member
  true = shards:member(?DUPLICATE_BAG, k1),
  true = ets:member(?ETS_DUPLICATE_BAG, k1),
  false = shards:member(?DUPLICATE_BAG, kx),
  false = ets:member(?ETS_DUPLICATE_BAG, kx),

  ct:print("\e[1;1m t_basic_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

t_match_ops(_Config) ->
  true = cleanup_shards(),

  % insert some values
  true = ets:insert(?ETS_SET, [{k1, 1}, {k2, 2}, {k3, 2}]),
  [true, true, true] = shards:insert(?SET, [{k1, 1}, {k2, 2}, {k3, 2}]),

  % match/2
  R1 = lists:usort(ets:match(?ETS_SET, '$1')),
  R1 = lists:usort(shards:match(?SET, '$1')),

  % match_object/2
  R2 = lists:usort(ets:match_object(?ETS_SET, '$1')),
  R2 = lists:usort(shards:match_object(?SET, '$1')),

  % match_delete/2
  true = ets:match_delete(?ETS_SET, {'$1', 2}),
  true = shards:match_delete(?SET, {'$1', 2}),
  R3 = lists:usort(ets:match_object(?ETS_SET, '$1')),
  R3 = lists:usort(shards:match_object(?SET, '$1')),
  1 = length(R3),

  ct:print("\e[1;1m t_match_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

t_select_ops(_Config) ->
  true = cleanup_shards(),

  % insert some values
  true = ets:insert(?ETS_SET, [{k1, 1}, {k2, 2}, {k3, 2}]),
  [true, true, true] = shards:insert(?SET, [{k1, 1}, {k2, 2}, {k3, 2}]),

  % select/2
  MS1 = ets:fun2ms(fun({K, V}) -> {K, V} end),
  R1 = lists:usort(ets:select(?ETS_SET, MS1)),
  R1 = lists:usort(shards:select(?SET, MS1)),
  3 = length(R1),

  % select_reverse/2
  R2 = lists:usort(ets:select_reverse(?ETS_SET, MS1)),
  R2 = lists:usort(shards:select_reverse(?SET, MS1)),
  3 = length(R2),

  % select_count/2
  MS2 = ets:fun2ms(fun({_K, V}) when V rem 2 == 0 -> true end),
  2 = ets:select_count(?ETS_SET, MS2),
  2 = shards:select_count(?SET, MS2),

  % select_delete/2
  2 = ets:select_delete(?ETS_SET, MS2),
  2 = shards:select_delete(?SET, MS2),
  R11 = lists:usort(ets:select(?ETS_SET, MS1)),
  R11 = lists:usort(shards:select(?SET, MS1)),
  1 = length(R11),

  ct:print("\e[1;1m t_select_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

t_paginated_ops(_Config) ->
  MS = ets:fun2ms(fun({K, V}) -> {K, V} end),
  Ops = [
    {select, MS},
    {select_reverse, MS},
    {match, '$1'},
    {match_object, '$1'}
  ],
  Args = [{Tab, Op} || Tab <- ?SHARDS_TABS, Op <- Ops],
  run_foreach(fun t_paginated_ops_/1, Args).

t_paginated_ops_({Tab, {Op, Q}} = Args) ->
  true = cleanup_shards(),

  % test empty
  '$end_of_table' = shards:Op(Tab, Q, 10),

  % insert some values
  KVPairs = [
    {k1, 1}, {k2, 2}, {k3, 2}, {k1, 1}, {k4, 22}, {k5, 33},
    {k11, 1}, {k22, 2}, {k33, 2}, {k44, 11}, {k55, 22}, {k55, 33}
  ],
  R0 = shards:insert(Tab, KVPairs),
  R0 = lists:duplicate(12, true),

  %% length
  Len = case Tab of
    ?DUPLICATE_BAG -> 12;
    _              -> 10
  end,

  % select/3
  {R1, C1} = shards:Op(Tab, Q, 1),
  1 = length(R1),
  {R2, _} = shards:Op(Tab, Q, 20),
  Len = length(R2),

  % select/1 - by 1
  {R11, Calls1} = select_by(Op, C1, 1),
  Calls1 = Len,
  R2 = R11 ++ R1,

  % select/1 - by 2
  {R3, C2} = shards:Op(Tab, Q, 2),
  2 = length(R3),
  {R22, Calls2} = select_by(Op, C2, 2),
  Calls2 = round(Len / 2),
  R2 = R22 ++ R3,

  % select/1 - by 4
  {R4, C3} = shards:Op(Tab, Q, 4),
  4 = length(R4),
  {R44, Calls3} = select_by(Op, C3, 4),
  Calls3 = round(Len / 4),
  R2 = R44 ++ R4,

  ct:print("\e[1;1m t_paginated_ops(~p): \e[0m\e[32m[OK] \e[0m", [Args]),
  ok.

t_first_last_next_prev_ops(_Config) ->
  true = cleanup_shards(),

  '$end_of_table' = shards:first(?SET),
  '$end_of_table' = shards:last(?SET),
  '$end_of_table' = shards:first(?ORDERED_SET),
  '$end_of_table' = shards:last(?ORDERED_SET),

  true = shards:insert(?SET, {k1, 1}),
  true = shards:insert(?ORDERED_SET, {k1, 1}),
  F1 = shards:first(?SET),
  F1 = shards:last(?SET),
  F1 = shards:first(?ORDERED_SET),
  F1 = shards:last(?ORDERED_SET),

  % insert some values
  KVPairs = [
    {k1, 1}, {k2, 2}, {k3, 2}, {k4, 22}, {k5, 33},
    {k11, 1}, {k22, 2}, {k33, 2}, {k44, 11}, {k55, 22}
  ],
  R0 = shards:insert(?SET, KVPairs),
  R0 = shards:insert(?ORDERED_SET, KVPairs),
  R0 = lists:duplicate(10, true),

  % match spec
  MS = ets:fun2ms(fun({K, V}) -> {K, V} end),

  % check first-next against select for 'set'
  L1 = [Last | _] = first_next_traversal(?SET, 10, []),
  '$end_of_table' = shards:next(?SET, Last),
  {L11, _} = shards:select(?SET, MS, 10),
  L1 = [K || {K, _} <- L11],

  % check first-next against select for 'ordered_set'
  L2 = [Last2 | _] = first_next_traversal(?ORDERED_SET, 10, []),
  '$end_of_table' = shards:next(?ORDERED_SET, Last2),
  {L22, _} = shards:select(?ORDERED_SET, MS, 10),
  L2 = [K || {K, _} <- L22],

  % check last-prev against select for 'set'
  L3 = [Last3 | _] = last_prev_traversal(?SET, 10, []),
  '$end_of_table' = shards:prev(?SET, Last3),
  {L33, _} = shards:select(?SET, MS, 10),
  L3 = L1 = [K || {K, _} <- L33],

  % check last-prev against select for 'ordered_set'
  L4 = [Last4 | _] = last_prev_traversal(?ORDERED_SET, 10, []),
  '$end_of_table' = shards:prev(?ORDERED_SET, Last4),
  {L44, _} = shards:select(?ORDERED_SET, MS, 10),
  L4 = [K || {K, _} <- lists:reverse(L44)],

  ct:print("\e[1;1m t_first_last_next_prev_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

t_update_ops(_Config) ->
  true = cleanup_shards(),

  % update counter
  ets:insert(?ETS_SET, {counter1, 0}),
  shards:insert(?SET, {counter1, 0}),
  R1 = ets:update_counter(?ETS_SET, counter1, 1),
  R1 = shards:update_counter(?SET, counter1, 1),

  % update with default
  R2 = ets:update_counter(?ETS_SET, counter2, 1, {counter2, 0}),
  R2 = shards:update_counter(?SET, counter2, 1, {counter2, 0}),

  % update element
  ets:insert(?ETS_SET, {elem0, 0}),
  shards:insert(?SET, {elem0, 0}),
  R3 = ets:update_element(?ETS_SET, elem0, {2, 10}),
  R3 = shards:update_element(?SET, elem0, {2, 10}),

  ct:print("\e[1;1m t_update_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

t_fold_ops(_Config) ->
  true = cleanup_shards(),

  % insert some values
  true = ets:insert(?ETS_SET, [{k1, 1}, {k2, 2}, {k3, 3}]),
  [true, true, true] = shards:insert(?SET, [{k1, 1}, {k2, 2}, {k3, 3}]),

  % foldl
  Foldl = fun({_, V}, Acc) -> [V | Acc] end,
  R1 = lists:usort(shards:foldl(Foldl, [], ?SET)),
  R1 = lists:usort(ets:foldl(Foldl, [], ?ETS_SET)),

  % foldr
  Foldr = fun({_, V}, Acc) -> [V | Acc] end,
  R2 = lists:usort(shards:foldr(Foldr, [], ?SET)),
  R2 = lists:usort(ets:foldr(Foldr, [], ?ETS_SET)),

  ct:print("\e[1;1m t_fold_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

t_info_ops(_Config) ->
  true = cleanup_shards(),

  % test i/0
  R0 = shards:i(),
  R0 = ets:i(),

  % test info/1,2
  2 = length(shards:info(?SET)),
  5 = length(shards:info(?DUPLICATE_BAG)),
  L1 = lists:duplicate(2, public),
  L1 = shards:info(?SET, protection),
  L2 = lists:duplicate(5, public),
  L2 = shards:info(?DUPLICATE_BAG, protection),

  % test info_shard/2,3
  SetShards = shards:list(?SET),
  ok = lists:foreach(fun({Shard, ShardName}) ->
    R1 = shards:info_shard(?SET, Shard),
    R1 = ets:info(ShardName)
  end, lists:zip(lists:seq(0, length(SetShards) - 1), SetShards)),
  ok = lists:foreach(fun({Shard, ShardName}) ->
    R1 = shards:info_shard(?SET, Shard, protection),
    R1 = ets:info(ShardName, protection)
  end, lists:zip(lists:seq(0, length(SetShards) - 1), SetShards)),

  % test info_shard/2,3
  DupBagShards = shards:list(?DUPLICATE_BAG),
  ok = lists:foreach(fun({Shard, ShardName}) ->
    R1 = shards:info_shard(?DUPLICATE_BAG, Shard),
    R1 = ets:info(ShardName)
  end, lists:zip(lists:seq(0, length(DupBagShards) - 1), DupBagShards)),
  ok = lists:foreach(fun({Shard, ShardName}) ->
    R1 = shards:info_shard(?DUPLICATE_BAG, Shard, protection),
    R1 = ets:info(ShardName, protection)
  end, lists:zip(lists:seq(0, length(DupBagShards) - 1), DupBagShards)),

  ct:print("\e[1;1m t_info_ops: \e[0m\e[32m[OK] \e[0m"),
  ok.

%%%===================================================================
%%% Internal functions
%%%===================================================================

init_shards() ->
  shards:new(?SET, [set]),
  shards:new(?DUPLICATE_BAG, [duplicate_bag], 5),
  shards:new(?ORDERED_SET, [ordered_set]),
  shards_created([?SET, ?DUPLICATE_BAG, ?ORDERED_SET]),
  ets:new(?ETS_SET, [set, public, named_table]),
  ets:new(?ETS_DUPLICATE_BAG, [duplicate_bag, public, named_table]),
  ets:new(?ETS_ORDERED_SET, [ordered_set, public, named_table]),
  ok.

cleanup_shards() ->
  L = lists:duplicate(3, true),
  L = [shards:delete_all_objects(Tab) || Tab <- ?SHARDS_TABS],
  L = [ets:delete_all_objects(Tab) || Tab <- ?ETS_TABS],
  All = [ets:match(Tab, '$1') || Tab <- ?ETS_TABS],
  All = [shards:match(Tab, '$1') || Tab <- ?SHARDS_TABS],
  true.

delete_shards_pool() ->
  L = lists:duplicate(3, true),
  L = [shards:delete(Tab) || Tab <- ?SHARDS_TABS],
  L = [ets:delete(Tab) || Tab <- ?ETS_TABS],
  [] = supervisor:count_children(shards_sup).

run_foreach(Fun, List) -> lists:foreach(Fun, List).

lookup_keys(Mod, Tab, Keys) ->
  lists:foldr(fun(Key, Acc) ->
    case Mod:lookup(Tab, Key) of
      [Value] -> [Value | Acc];
      _       -> Acc
    end
  end, [], Keys).

shards_created(TabL) when is_list(TabL) ->
 lists:foreach(fun shards_created/1, TabL);
shards_created(Tab) ->
  lists:foreach(fun(Shard) ->
    true = lists:member(Shard, shards:all())
  end, shards:list(Tab)).

select_by(Op, Continuation, Limit) ->
  select_by(Op, shards:Op(Continuation), Limit, {[], 1}).

select_by(_, '$end_of_table', _, Acc) ->
  Acc;
select_by(Op, {L, Continuation}, Limit, {Acc, Calls}) ->
  select_by(Op, shards:Op(Continuation), Limit, {L ++ Acc, Calls + 1}).

first_next_traversal(_, 0, Acc) ->
  Acc;
first_next_traversal(_, _, ['$end_of_table' | Acc]) ->
  Acc;
first_next_traversal(Tab, Limit, []) ->
  first_next_traversal(Tab, Limit - 1, [shards:first(Tab)]);
first_next_traversal(Tab, Limit, [Key | _] = Acc) ->
  first_next_traversal(Tab, Limit - 1, [shards:next(Tab, Key) | Acc]).

last_prev_traversal(_, 0, Acc) ->
  Acc;
last_prev_traversal(_, _, ['$end_of_table' | Acc]) ->
  Acc;
last_prev_traversal(Tab, Limit, []) ->
  last_prev_traversal(Tab, Limit - 1, [shards:last(Tab)]);
last_prev_traversal(Tab, Limit, [Key | _] = Acc) ->
  last_prev_traversal(Tab, Limit - 1, [shards:prev(Tab, Key) | Acc]).