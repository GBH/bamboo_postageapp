# Bamboo.PostageAppAdapter [![Hex.pm](https://img.shields.io/hexpm/v/bamboo_postageapp.svg?style=flat)](https://hex.pm/packages/bamboo_postageapp) [![Build Status](https://travis-ci.org/GBH/bamboo_postageapp.svg?style=flat&branch=master)](https://travis-ci.org/GBH/bamboo_postageapp)


A [PostageApp](https://postageapp.com/) Adapter for the [Bamboo](https://github.com/thoughtbot/bamboo) email library.


### [API Documentation](http://help.postageapp.com/kb/api/api-overview) &bull; [Knowledge Base](http://help.postageapp.com/kb) &bull; [Help Portal](http://help.postageapp.com/)

## Installation

Add `bamboo_postageapp` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:bamboo_postageapp, "~> 0.0.1"}]
end
```

Add PostageApp to your config:

```elixir
# In your configuration file:
#  * General configuration: config/config.exs
#  * Recommended production only: config/prod.exs
#
# `recipient_override` setting is useful for staging environment when you might
# have real users and don't want to send emails to them.

config :my_app, MyApp.Mailer,
  adapter: Bamboo.PostageAppAdapter,
  api_key: "API_KEY",
  recipient_override: "override@example.org"
```

## PostageApp specific email helpers

PostageApp allows you to use custom message templates and apply variables like so:

```elixir
defmodule MyApp.Mail do
  import Bamboo.PostageAppHelper

  def some_email do
    new_email()
    |> to("to@example.com")
    |> postageapp_template("template-name")
    |> postageapp_variables(%{foo: "123", bar: "abc"})
  end
end
```

# Copyright

(C) 2017 Oleg Khabarov
