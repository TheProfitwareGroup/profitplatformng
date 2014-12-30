profitplatform-ng
=============

**ProfitPlatform reincarnation.**

Author: Sergey Sobko <S.Sobko@profitware.ru>

## Introduction

ProfitPlatform is a software built on top of RabbitMQ using Erlang/OTP. It is capable of getting requests through 
JSON-RPC and executing Python code from [MessageAPI](https://github.com/TheProfitwareGroup/messageapi/).

## Getting the code

The code is hosted at [GitHub](https://github.com/TheProfitwareGroup/profitplatformng/).

Check out the latest development version anonymously with:

```
 $ git clone git://github.com/TheProfitwareGroup/profitplatformng.git
 $ cd profitplatformng
```

## Message queue server

ProfitPlatform depends on [RabbitMQ server](http://www.rabbitmq.com/download.html). It must be installed first.

## Building

From source:

Install the dependencies:

- [Rebar](https://github.com/basho/rebar/) (may be installed using your package manager)
- [Rebar-friendly version of AMQP client library](https://github.com/jbrisbin/amqp_client/)
- [ErlPort](https://github.com/hdima/erlport/)

In order to use message channels, first you need to 
install [MessageAPI](https://github.com/TheProfitwareGroup/messageapi/).

Getting dependencies (after Rebar is installed):

    $ rebar get-deps

Compilation:

    $ rebar compile

## Usage

To run development environment (run more times to get automatically configured cloud instances) 
```
$ cp default.config.example default.config
$ erl -pa ebin deps/*/ebin -eval "application:start(profitplatformng)" -config default
```

Publish message using SMSCPlugin from MessageAPI (default.config must be configured properly):

    1> profitplatformng_mq:publish(smsc, [{phones, '79xxxxxxxxx'}, {message, 'Hello, world!'}]).

