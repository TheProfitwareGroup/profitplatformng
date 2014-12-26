%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Queue worker supervisor.
%%% @end
%%% Created : 15.10.2014 15:53
%%%-------------------------------------------------------------------

-module(profitplatformng_worker_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).
-export([create_worker/1]).

%% Supervisor callbacks
-export([init/1]).

%% Definitions
-include_lib("profitplatformng/include/profitplatformng.hrl").
-define(SERVER, ?MODULE).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?SERVER, []).

create_worker(QueueIdentifier) ->
    io:format("Starting child ~s~n", [QueueIdentifier]),
    supervisor:start_child(?SERVER, [QueueIdentifier]).

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    Flags = {simple_one_for_one, ?MAX_RESTART, ?MAX_TIME},
    Spec = [
        ?CHILD(profitplatformng_worker, worker, transient)
    ],
    {ok, {Flags, Spec}}.
