%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Message queue connection
%%% @end
%%% Created : 19.10.2014 17:22
%%%-------------------------------------------------------------------
-module(profitplatformng_mq_connection).
-author("ssobko").

-behaviour (gen_server).

%% API
-export([start_link/0]).
-export([get_channel/0, close_channel/1, reconnect/0]).

%% Server callbacks
-export([init/1, terminate/2, code_change/3]).
-export([handle_call/3, handle_cast/2, handle_info/2]).

%% Definitions
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("profitplatformng/include/profitplatformng.hrl").
-define (SERVER, ?MODULE).

-record(state, {connection}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

get_channel() ->
    gen_server:call(?SERVER, get_channel).

close_channel(Channel) ->
    gen_server:call(?SERVER, {close_channel, Channel}).

reconnect() ->
    gen_server:call(?SERVER, reconnect).

%% ===================================================================
%% Server callbacks
%% ===================================================================

init(_Args) ->
    State = create_connection(),
    {ok, State}.

handle_call(get_channel, _From, State) ->
    {ok, Channel} = amqp_connection:open_channel(get_state_connection(State)),
    {reply, Channel, State};

handle_call({close_channel, Channel}, _From, State) ->
    amqp_channel:close(Channel),
    {reply, ok, State};

handle_call(reconnect, _From, State) ->
    close_connection(State),
    NewState = create_connection(),
    {reply, ok, NewState};

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    close_connection(State),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-spec create_connection() -> #state{}.
create_connection() ->
    ConnectionParams = profitplatformng_config:get(rabbitmq, amqp_params),
    {ok, Connection} = amqp_connection:start(ConnectionParams),
    init_state(Connection).

-spec close_connection(#state{}) -> ok.
close_connection(State) ->
    amqp_connection:close(get_state_connection(State)),
    ok.

-spec init_state(any) -> #state{}.
init_state(Connection) ->
    #state{
        connection = Connection
    }.

-spec get_state_connection(#state{}) -> any.
get_state_connection(State) ->
    State#state.connection.

