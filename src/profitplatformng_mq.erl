%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Message queue
%%% @end
%%% Created : 19.10.2014 17:22
%%%-------------------------------------------------------------------
-module(profitplatformng_mq).
-author("ssobko").

-behaviour (gen_server).

%% API
-export([start_link/0]).
-export([publish/2]).

%% Server callbacks
-export([init/1, terminate/2, code_change/3]).
-export([handle_call/3, handle_cast/2, handle_info/2]).

%% Definitions
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("profitplatformng/include/profitplatformng.hrl").
-define (SERVER, ?MODULE).

-record(state, {connection, channel, statequeue}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec publish(Queue :: atom(), Payload :: binary()) -> ok.
publish(Queue, Payload) ->
    gen_server:cast(?SERVER, {publish, Queue, Payload}),
    ok.

%% ===================================================================
%% Server callbacks
%% ===================================================================

init(_Args) ->
    ConnectionParams = profitplatformng_config:get(rabbitmq, amqp_params),
    {ok, Connection} = amqp_connection:start(ConnectionParams),
    {ok, Channel} = amqp_connection:open_channel(Connection),

    % Global queue to broadcast new queue names
    StateQueueIdentifier = <<?MQPREFIX/binary, <<"state">>/binary>>,

    DeclareExchange = #'exchange.declare'{exchange = StateQueueIdentifier, type = <<"fanout">>},
    #'exchange.declare_ok'{} = amqp_channel:call(Channel, DeclareExchange),

    DeclareQueue = #'queue.declare'{queue = StateQueueIdentifier},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, DeclareQueue),

    Binding = #'queue.bind'{
        queue = StateQueueIdentifier,
        exchange = StateQueueIdentifier
    },
    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),

    Sub = #'basic.consume'{queue = StateQueueIdentifier},
    #'basic.consume_ok'{consumer_tag = _StateQueueTag} = amqp_channel:call(Channel, Sub),

    {ok, init_state(Connection, Channel, StateQueueIdentifier)}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({publish, Queue, Payload}, State) ->
    Channel = get_state_channel(State),

    % Get fully qualified message queue name
    QueuePartIdentifierBinary = atom_to_binary(Queue, latin1),
    QueueIdentifier = <<?MQPREFIX/binary, QueuePartIdentifierBinary/binary>>,

    % Broadcast queue name for workers to subscribe
    StateQueueIdentifier = get_state_statequeue(State),
    StateQueue = #'queue.declare'{queue = StateQueueIdentifier},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, StateQueue),

    StateQueuePublish = #'basic.publish'{exchange = StateQueueIdentifier},
    amqp_channel:cast(Channel, StateQueuePublish, #amqp_msg{payload = QueueIdentifier}),

    % Check or create queue
    DeclareQueue = #'queue.declare'{queue = QueueIdentifier},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, DeclareQueue),

    Publish = #'basic.publish'{exchange = <<>>, routing_key = QueueIdentifier},
    amqp_channel:cast(Channel, Publish, #amqp_msg{payload = Payload}),
    {noreply, State};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(Info, State) ->
    case Info of
        {#'basic.deliver'{delivery_tag = Tag}, Content} ->
            Channel = get_state_channel(State),
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
            {amqp_msg, _ClassType, QueueIdentifier} = Content,

            %% FIXME: simple_one_for_one supervisor creates child process which subscribes QueueIdentifier queue
            io:format("Got queue name: ~s~n", [QueueIdentifier]);
        _Others ->
            ok
    end,
    {noreply, State}.

terminate(_Reason, State) ->
    amqp_channel:close(get_state_channel(State)),
    amqp_connection:close(get_state_connection(State)),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-spec init_state(any, any, any) -> #state{}.
init_state(Connection, Channel, StateQueue) ->
    #state{
        connection = Connection,
        channel = Channel,
        statequeue = StateQueue
    }.

-spec get_state_connection(#state{}) -> any.
get_state_connection(State) ->
    State#state.connection.

-spec get_state_channel(#state{}) -> any.
get_state_channel(State) ->
    State#state.channel.

-spec get_state_statequeue(#state{}) -> any.
get_state_statequeue(State) ->
    State#state.statequeue.