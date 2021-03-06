%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Main application supervisor.
%%% @end
%%% Created : 15.10.2014 15:53
%%%-------------------------------------------------------------------

-module(profitplatformng_sup).

-behaviour(supervisor).

%% API
-export([start_link/0]).

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

%% ===================================================================
%% Supervisor callbacks
%% ===================================================================

init([]) ->
    Flags = {one_for_one, ?MAX_RESTART, ?MAX_TIME},
    Spec = [
        ?CHILD(profitplatformng_config, worker, permanent),
        ?CHILD(profitplatformng_mq_connection, worker, permanent),
        ?CHILD(profitplatformng_mq, worker, permanent),
        ?CHILD(profitplatformng_worker_sup, supervisor, permanent)
    ],
    {ok, {Flags, Spec}}.
