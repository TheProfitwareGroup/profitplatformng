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

-record(state, {channel, state_exchange, state_queue, created_queues = []}).

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
    Channel = profitplatformng_mq_connection:get_channel(),

    % Global queue to broadcast new queue names
    StateExchangeIdentifier = <<?MQPREFIX/binary, <<"state">>/binary>>,

    DeclareExchange = #'exchange.declare'{exchange = StateExchangeIdentifier},
    #'exchange.declare_ok'{} = amqp_channel:call(Channel, DeclareExchange),

    DeclareQueue = #'queue.declare'{auto_delete = true},
    #'queue.declare_ok'{queue = DeclareQueueIdentifier} = amqp_channel:call(Channel, DeclareQueue),

    Binding = #'queue.bind'{
        queue = DeclareQueueIdentifier,
        exchange = StateExchangeIdentifier,
        routing_key = StateExchangeIdentifier
    },
    #'queue.bind_ok'{} = amqp_channel:call(Channel, Binding),

    Sub = #'basic.consume'{queue = DeclareQueueIdentifier},
    #'basic.consume_ok'{consumer_tag = _StateQueueTag} = amqp_channel:call(Channel, Sub),

    {ok, init_state(Channel, StateExchangeIdentifier, DeclareQueueIdentifier)}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast({publish, Queue, Payload}, State) ->
    Channel = get_state_channel(State),

    % Get fully qualified message queue name
    QueuePartIdentifierBinary = atom_to_binary(Queue, latin1),
    QueueIdentifier = <<?MQPREFIX/binary, QueuePartIdentifierBinary/binary>>,

    StateExchangeIdentifier = get_state_state_exchange(State),

    StateQueuePublish = #'basic.publish'{exchange = StateExchangeIdentifier, routing_key = StateExchangeIdentifier},
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

            NewState = add_state_created_queue(State, QueueIdentifier),
            io:format("Got queue name: ~s~n", [QueueIdentifier]);
        _Others ->
            NewState = State
    end,
    {noreply, NewState}.

terminate(_Reason, State) ->
    profitplatformng_mq_connection:close_channel(get_state_channel(State)),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-spec init_state(any, any, any) -> #state{}.
init_state(Channel, StateExchange, StateQueue) ->
    #state{
        channel = Channel,
        state_exchange = StateExchange,
        state_queue = StateQueue
    }.

-spec get_state_channel(#state{}) -> any.
get_state_channel(State) ->
    State#state.channel.

-spec get_state_state_exchange(#state{}) -> any.
get_state_state_exchange(State) ->
    State#state.state_exchange.

-spec get_state_created_queues(#state{}) -> any.
get_state_created_queues(State) ->
    State#state.created_queues.

-spec add_state_created_queue(#state{}, binary) -> true | false.
add_state_created_queue(State, QueueIdentifier) ->
    CreatedQueues = get_state_created_queues(State),
    case lists:member(QueueIdentifier, CreatedQueues) of
        false ->
            profitplatformng_worker_sup:create_worker(QueueIdentifier),
            NewList = lists:append(CreatedQueues, [QueueIdentifier]);
        true ->
            NewList = get_state_created_queues(State)
    end,
    State#state{created_queues = NewList}.