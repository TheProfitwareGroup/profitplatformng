%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Message queue worker
%%% @end
%%% Created : 19.10.2014 17:22
%%%-------------------------------------------------------------------
-module(profitplatformng_worker).
-author("ssobko").

-behaviour (gen_server).

%% API
-export([start_link/1]).

%% Server callbacks
-export([init/1, terminate/2, code_change/3]).
-export([handle_call/3, handle_cast/2, handle_info/2]).

%% Definitions
-include_lib("amqp_client/include/amqp_client.hrl").
-include_lib("profitplatformng/include/profitplatformng.hrl").
-define (SERVER, ?MODULE).

-record(state, {channel, queue, python}).

%% ===================================================================
%% API functions
%% ===================================================================

start_link(QueueIdentifier) ->
    gen_server:start_link(?SERVER, [QueueIdentifier], []).

%% ===================================================================
%% Server callbacks
%% ===================================================================

init([QueueIdentifier]) ->
    Channel = profitplatformng_mq_connection:get_channel(),

    % Subscribe to specified queue
    DeclareQueue = #'queue.declare'{queue = QueueIdentifier},
    #'queue.declare_ok'{} = amqp_channel:call(Channel, DeclareQueue),

    Sub = #'basic.consume'{queue = QueueIdentifier},
    #'basic.consume_ok'{consumer_tag = _StateQueueTag} = amqp_channel:call(Channel, Sub),

    io:format("Consumed to queue ~s~n", [QueueIdentifier]),

    {ok, Python} = python:start_link(profitplatformng_config:get(python, config)),
    PythonClassConfig = profitplatformng_config:get(python, binary_to_atom(QueueIdentifier, latin1)),
    PythonClass = proplists:get_value(python_class, PythonClassConfig),
    PythonClassParams = proplists:get_value(params, PythonClassConfig),
    python:call(Python, messageapi, messageapi_factory, [PythonClass, PythonClassParams]),

    {ok, init_state(Channel, QueueIdentifier, Python)}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(Info, State) ->
    case Info of
        {#'basic.deliver'{delivery_tag = Tag}, Content} ->
            Channel = get_state_channel(State),
            amqp_channel:cast(Channel, #'basic.ack'{delivery_tag = Tag}),
            {amqp_msg, _ClassType, Message} = Content,

            io:format("Got message '~s' to queue ~s~n", [Message, get_state_queue(State)]),
            Python = get_state_python(State)

            % FIXME: Call MessageAPI send_message function

            ;
        _Others ->
            ok
    end,
    {noreply, State}.

terminate(_Reason, State) ->
    profitplatformng_mq_connection:close_channel(get_state_channel(State)),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% ===================================================================
%% Internal functions
%% ===================================================================

-spec init_state(any, any, any) -> #state{}.
init_state(Channel, Queue, Python) ->
    #state{
        channel = Channel,
        queue = Queue,
        python = Python
    }.

-spec get_state_channel(#state{}) -> any.
get_state_channel(State) ->
    State#state.channel.

-spec get_state_queue(#state{}) -> any.
get_state_queue(State) ->
    State#state.queue.

-spec get_state_python(#state{}) -> any.
get_state_python(State) ->
    State#state.python.