%%% @doc Redis repository implementation.
%%%
%%% Copyright 2012 Marcelo Gornstein &lt;marcelog@@gmail.com&gt;
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%% @end
%%% @copyright Marcelo Gornstein <marcelog@gmail.com>
%%% @author Marcelo Gornstein <marcelog@gmail.com>
%%%
-module(sumo_repo_redis).
-author("Marcelo Gornstein <marcelog@gmail.com>").
-github("https://github.com/marcelog").
-homepage("http://marcelog.github.com/").
-license("Apache License 2.0").

-include_lib("include/sumo_doc.hrl").
-include_lib("eredis/include/eredis.hrl").

-behavior(sumo_repo).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Exports.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Public API.
-export([
  init/1, create_schema/2, persist/2, find_by/3, find_by/5,
  delete/3, delete_all/2, execute/2, execute/3
]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Types.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-record(state, {c::pid()}).
-type state() :: #state{}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% External API.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
persist(#sumo_doc{name=DocName, fields=Fields}=Doc, State) ->
  % Set the real id, replacing undefined by 0 so it is autogenerated
  IdField = sumo:field_name(sumo:get_id_field(DocName)),
  NewId = case sumo:get_field(IdField, Doc) of
    undefined -> generate_id(DocName, State);
    Id -> Id
  end,
  NewDoc = sumo:set_field(IdField, NewId, Doc),
  SDocName = atom_to_list(DocName),
  NewIdList = integer_to_list(NewId),
  Name = SDocName ++ ":" ++ NewIdList,
  % XXX Optimize, use pipelining
  lists:foreach(
    fun({FieldName, Value}) ->
      execute("HSET", [Name, atom_to_list(FieldName), Value], State)
    end,
    NewDoc#sumo_doc.fields
  ),
  {ok, NewDoc, State}.

delete(DocName, Id, State) ->
  ok.

delete_all(DocName, State) ->
  ok.

find_by(DocName, Conditions, Limit, Offset, State) ->
  ok.

find_by(DocName, Conditions, State) ->
  find_by(DocName, Conditions, 0, 0, State).

create_schema(_Schema, State) ->
  {ok, State}.

execute(Query, Args, #state{c=C}) when is_list(Query), is_list(Args) ->
  case eredis:q(C, [Query|Args]) of
    {ok, Result} -> Result;
    {ok} -> ok;
    Error -> {error, Error}
  end.

execute(Query, State) ->
  execute(Query, [], State).

generate_id(DocName, State) ->
  Id = execute("INCR", [atom_to_list(DocName)], State),
  list_to_integer(binary_to_list(Id)).

init(Options) ->
  {ok, C} = eredis:start_link(
    proplists:get_value(host, Options, "localhost"),
    proplists:get_value(port, Options, 6379),
    proplists:get_value(database, Options, ""),
    proplists:get_value(password, Options, ""),
    proplists:get_value(reconnect_sleep, Options, 100)
  ),
  {ok, #state{c=C}}.

