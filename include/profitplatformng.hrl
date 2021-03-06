%%%-------------------------------------------------------------------
%%% @author ssobko
%%% @copyright (C) 2014, The Profitware Group
%%% @doc
%%% Common definitions for profitplatform-ng
%%% @end
%%% Created : 18.10.2014 18:33
%%%-------------------------------------------------------------------
-author("ssobko").

-define(CRLF, [10]).

%% Helper macro for declaring children of supervisor
-define(CHILD(I, Type, Restart), {I, {I, start_link, []}, Restart, 5000, Type, [I]}).

%% Default values for supervisors
-define(MAX_RESTART, 5).
-define(MAX_TIME, 60).

%% Profitplatform specific definitions
-define(MQPREFIX, <<"profitplatform_queue_">>).