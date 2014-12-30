%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Configuration manager
%%% @end
%%% Created : 19.10.2014 17:22
%%%-------------------------------------------------------------------
-module(profitplatformng_config).
-author("ssobko").

-behaviour (gen_server).

%% API
-export([start_link/0]).
-export([get/2, get/3]).

%% Server callbacks
-export([init/1, terminate/2, code_change/3]).
-export([handle_call/3, handle_cast/2, handle_info/2]).

%% Definitions
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("profitplatformng/include/profitplatformng.hrl").
-define (SERVER, ?MODULE).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec get(Group :: atom(), Key :: atom()) -> any().
get(Group, Key) ->
    gen_server:call(?SERVER, {get, Group, Key, false}).

-spec get(Group :: atom(), Key :: atom(), UseDefault :: true | false) -> any().
get(Group, Key, UseDefault) ->
    gen_server:call(?SERVER, {get, Group, Key, UseDefault}).


%% ===================================================================
%% Server callbacks
%% ===================================================================

init(_Args) ->
    {ok, state}.

handle_call({get, Group, Key, UseDefault}, _From, State) ->
    Reply = case application:get_env(profitplatformng, Group) of
        undefined ->
            case UseDefault of
                false ->
                    {error, nogroup, Group};
                true ->
                    default(Group, Key)
            end;
        {ok, Found} ->
            case UseDefault of
                false ->
                    proplists:get_value(Key, Found);
                true ->
                    proplists:get_value(Key, Found, default(Group, Key))
            end
    end,
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-spec default(Group :: atom(), Key :: atom()) -> any().
default(rabbitmq, amqp_params) -> #amqp_params_network{};
default(python, config) -> {}.